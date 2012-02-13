/** @file master.c
 *  @brief Format an Etherbone request.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Prepare a records in two phases:
 *   1. Determine how many operations we can pack.
 *   2. Format the actual payload.
 *
 *  @author Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 *  @bug None!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */

#define ETHERBONE_IMPL

#include <string.h>

#include "../glue/operation.h"
#include "../glue/cycle.h"
#include "../glue/device.h"
#include "../glue/socket.h"
#include "../transport/transport.h"
#include "../memory/memory.h"
#include "format.h"
#include "bigendian.h"

static inline void EB_mWRITE(uint8_t* wptr, eb_data_t val, int alignment) {
  switch (alignment) {
  case 2: *(uint16_t*)wptr = htobe16(val); break;
  case 4: *(uint32_t*)wptr = htobe32(val); break;
  case 8: *(uint64_t*)wptr = htobe64(val); break;
  }
}

/* This method is tricky.
 * Whenever a callback or an allocation happens, dereferenced pointers become invalid.
 * Thus, the EB_<TYPE>(x) conversions appear late and near their use.
 */
void eb_device_flush(eb_device_t devicep) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_device* device;
  struct eb_link* link;
  struct eb_transport* transport;
  struct eb_cycle* cycle;
  struct eb_response* response;
  eb_cycle_t cyclep, nextp, prevp;
  eb_response_t responsep;
  eb_width_t biggest, data;
  uint8_t buffer[sizeof(eb_max_align_t)*(255+255+1+1)+8]; /* big enough for worst-case record */
  uint8_t * wptr, * cptr, * eob;
  int alignment, record_alignment, header_alignment, stride, mtu, readback;
  
  device = EB_DEVICE(devicep);
  transport = EB_TRANSPORT(device->transport);
  
  // assert (device->passive != devicep);
  // assert (eb_width_refined(device->widths) != 0);
  
  /* Calculate alignment values */
  data = device->widths & EB_DATAX;
  biggest = (device->widths >> 4) | data;
  alignment = 2;
  alignment += (biggest >= EB_DATA32)*2;
  alignment += (biggest >= EB_DATA64)*4;
  record_alignment = 4;
  record_alignment += (biggest >= EB_DATA64)*4;
  header_alignment = record_alignment;
  stride = 1;
  stride += (data >= EB_DATA16)*1;
  stride += (data >= EB_DATA32)*2;
  stride += (data >= EB_DATA64)*4;
  
  /* Non-streaming sockets need a header */
  mtu = eb_transports[transport->link_type].mtu;
  if (mtu != 0) {
    memset(&buffer[0], 0, header_alignment);
    buffer[0] = 0x4E;
    buffer[1] = 0x6F;
    buffer[2] = 0x10; /* V1. no probe. */
    buffer[3] = device->widths;
    cptr = wptr = &buffer[header_alignment];
    eob = &buffer[mtu];
  } else {
    cptr = wptr = &buffer[0];
    eob = &buffer[sizeof(buffer)];
  }
  
  /* Invert the list of cycles */
  prevp = EB_NULL;
  for (cyclep = device->ready; cyclep != EB_NULL; cyclep = nextp) {
    cycle = EB_CYCLE(cyclep);
    nextp = cycle->next;
    cycle->next = prevp;
    prevp = cyclep;
  }
  
  for (cyclep = prevp; cyclep != EB_NULL; cyclep = nextp) {
    struct eb_operation* operation;
    struct eb_operation* scan;
    eb_operation_t operationp;
    eb_operation_t scanp;
    int needs_check;
    unsigned int ops, maxops;
    
    cycle = EB_CYCLE(cyclep);
    nextp = cycle->next;
    
    /* Deal with OOM cases */
    if (cycle->dead == cyclep) {
      if (cycle->callback)
        (*cycle->callback)(cycle->user_data, EB_NULL, EB_OOM);
      eb_free_cycle(cyclep);
      continue;
    }
    
    /* Was the cycle a no-op? */
    if (cycle->first == EB_NULL) {
      if (cycle->callback)
        (*cycle->callback)(cycle->user_data, EB_NULL, EB_OK);
      eb_free_cycle(cyclep);
      continue;
    }
    
    /* Record to hook it into socket */
    responsep = eb_new_response(); /* invalidates: cycle device transport */
    if (responsep == EB_NULL) {
      cycle = EB_CYCLE(cyclep);
      if (cycle->callback)
        (*cycle->callback)(cycle->user_data, EB_NULL, EB_OOM);
      eb_cycle_destroy(cyclep);
      eb_free_cycle(cyclep);
      continue;
    }

    /* Refresh pointers typically needed per cycle */
    device = EB_DEVICE(devicep);
    cycle = EB_CYCLE(cyclep);
    socket = EB_SOCKET(device->socket);
    response = EB_RESPONSE(responsep);
    aux = EB_SOCKET_AUX(socket->aux);
    
    operationp = cycle->first;
    operation = EB_OPERATION(operationp);
    
    needs_check = (operation->flags & EB_OP_CHECKED) != 0;
    if (needs_check) {
      maxops = stride * 8;
    } else {
      maxops = -1; 
    }
    
    /* Begin formatting the packet into records */
    ops = 0;
    readback = 0;
    while (operationp != EB_NULL || (needs_check && ops > 0)) {
      int wcount, rcount, rxcount, total, length, fifo, cycle_end;
      eb_address_t bwa;
      eb_operation_flags_t rcfg, wcfg;
      
      scanp = operationp;
      
      /* First pack writes into a record, if any */
      if (ops >= maxops ||
          scanp == EB_NULL ||
          ((scan = EB_OPERATION(scanp))->flags & EB_OP_MASK) != EB_OP_WRITE) {
        /* No writes in this record */
        wcount = 0;
        fifo = 0;
        wcfg = 0;
      } else {
        wcfg = scan->flags & EB_OP_CFG_SPACE;
        bwa = scan->address;
        scanp = scan->next;
        
        if (wcfg == 0) ++ops;
        
        /* How many writes can we chain? must be either FIFO or sequential in same address space */
        if (ops >= maxops ||
            scanp == EB_NULL ||
            ((scan = EB_OPERATION(scanp))->flags & EB_OP_MASK) != EB_OP_WRITE ||
            (scan->flags & EB_OP_CFG_SPACE) != wcfg) {
          /* Only a single write */
          fifo = 0;
          wcount = 1;
        } else {
          /* Consider if FIFO or sequential work */
          if (scan->address == bwa) {
            /* FIFO -- count how many ops we can chain */
            fifo = 1;
            wcount = 2;
            if (wcfg == 0) ++ops;
            
            for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
              scan = EB_OPERATION(scanp);
              if (scan->address != bwa) break;
              if ((scan->flags & EB_OP_MASK) != EB_OP_WRITE) break;
              if ((scan->flags & EB_OP_CFG_SPACE) != wcfg) break;
              if (wcount >= 255) break;
              if (ops >= maxops) break;
              if (wcfg == 0) ++ops;
              ++wcount;
            }
          } else if (scan->address == (bwa += stride)) {
            /* Sequential */
            fifo = 0;
            wcount = 2;
            if (wcfg == 0) ++ops;
            
            for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
              scan = EB_OPERATION(scanp);
              if (scan->address != (bwa += stride)) break;
              if ((scan->flags & EB_OP_MASK) != EB_OP_WRITE) break;
              if ((scan->flags & EB_OP_CFG_SPACE) != wcfg) break;
              if (wcount >= 255) break;
              if (ops >= maxops) break;
              if (wcfg == 0) ++ops;
              ++wcount;
            }
          } else {
            /* Cannot chain writes */
            fifo = 0;
            wcount = 1;
          }
        }
      }

      /* Next, how many reads follow? */
      /* First pack writes into a record, if any */
      if (ops >= maxops ||
          scanp == EB_NULL ||
          ((scan = EB_OPERATION(scanp))->flags & EB_OP_MASK) == EB_OP_WRITE) {
        /* No reads in this record */
        rcount = 0;
        rcfg = 0;
      } else {
        rcfg = scan->flags & EB_OP_CFG_SPACE;
        if (rcfg == 0) ++ops;
        
        rcount = 1;
        for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
          scan = EB_OPERATION(scanp);
          if ((scan->flags & EB_OP_MASK) == EB_OP_WRITE) break;
          if ((scan->flags & EB_OP_CFG_SPACE) != rcfg) break;
          if (rcount >= 255) break;
          if (ops >= maxops) break;
          if (rcfg == 0) ++ops;
          ++rcount;
        }
      }
      
      if (rcount == 0 && (ops >= maxops || (scanp == EB_NULL && needs_check && ops > 0))) {
        /* Insert error-flag read */
        rxcount = 1;
        rcfg = 1;
      } else {
        rxcount = rcount;
      }
      
      /* Compute total request length */
      total = (wcount  > 0) + wcount
            + (rxcount > 0) + rxcount;
      
      length = record_alignment + total*alignment;
      
      /* Ensure sufficient buffer space */
      if (length > eob - wptr) {
        /* Refresh pointers */
        transport = EB_TRANSPORT(device->transport);
        link = EB_LINK(device->link);
        
        if (mtu == 0) {
          /* Overflow in a streaming device => flush and continue */
          (*eb_transports[transport->link_type].send)(transport, link, &buffer[0], wptr - &buffer[0]);
          wptr = &buffer[0];
        } else {
          /* Overflow in a packet-based device, send any previous cycles and keep current */
          
          /* Already contains a prior cycle -- flush it */
          if (cptr != &buffer[header_alignment]) {
            int send, keep;
            
            send = cptr - &buffer[0];
            (*eb_transports[transport->link_type].send)(transport, link, &buffer[0], send);
            
            /* Shift any existing records over */
            keep = wptr - cptr;
            memmove(&buffer[header_alignment], cptr, keep);
            cptr = &buffer[header_alignment];
            wptr = cptr + keep;
          }
          
          /* Test for cycle overflow of MTU */
          if (length > eob - wptr) {
            /* Blow up in the face of the user */
            if (cycle->callback)
              (*cycle->callback)(cycle->user_data, cycle->first, EB_OVERFLOW);
            eb_cycle_destroy(cyclep);
            eb_free_cycle(cyclep);
            eb_free_response(responsep);
            
            /* Start next cycle at the head of buffer */
            wptr = &buffer[header_alignment];
            break; /* Exits while(), continues for() due to conditional after while() */
          }
        }
      }
      
      /* The last record in a cycle if: */
      cycle_end = 
        scanp == EB_NULL &&
        (!needs_check || ops == 0 || rxcount != rcount);
      
      /* Start by preparting the header */
      memset(wptr, 0, record_alignment);
      wptr[0] = EB_RECORD_BCA | EB_RECORD_RFF | /* BCA+RFF always set */
                (rcfg ? EB_RECORD_RCA : 0) |
                (wcfg ? EB_RECORD_WCA : 0) | 
                (fifo ? EB_RECORD_WFF : 0) |
                (cycle_end ? EB_RECORD_CYC : 0);
      wptr[1] = 0;
      wptr[2] = wcount;
      wptr[3] = rxcount;
      wptr += record_alignment;
      
      /* Fill in the writes */
      if (wcount > 0) {
        operation = EB_OPERATION(operationp);
        
        EB_mWRITE(wptr, operation->address, alignment);
        wptr += alignment;
        
        for (; wcount--; operationp = operation->next) {
          operation = EB_OPERATION(operationp);
          
          EB_mWRITE(wptr, operation->write_value, alignment);
          wptr += alignment;
        }
      }
      
      /* Insert the read-back */
      if (rxcount != rcount) {
        readback = 1;
        
        EB_mWRITE(wptr, aux->rba|1, alignment);
        wptr += alignment;
        
        /* Status register is read at differing offset for differing port widths */
        EB_mWRITE(wptr, 8 - stride, alignment);
        wptr += alignment;
        
        ops = 0;
      }
      
      /* Fill in the reads */
      if (rcount > 0) {
        readback = 1;
        
        EB_mWRITE(wptr, aux->rba, alignment);
        wptr += alignment;
        
        for (; rcount--; operationp = operation->next) {
          operation = EB_OPERATION(operationp);
          
          EB_mWRITE(wptr, operation->address, alignment);
          wptr += alignment;
        }
      }
    }
    
    /* Did we finish the while loop? */
    if (operationp == EB_NULL && (!needs_check || ops == 0)) {
      if (readback == 0) {
        /* No response will arrive, so call callback now */
        if (cycle->callback)
          /* Invalidates pointers, but jumps to top of loop afterwards */
          (*cycle->callback)(cycle->user_data, cycle->first, EB_OK); 
        eb_cycle_destroy(cyclep);
        eb_free_cycle(cyclep);
        eb_free_response(responsep);
      } else {
        /* Setup a response */
        response->deadline = aux->time_cache + 5;
        response->cycle = cyclep;
        response->write_cursor = eb_find_read(cycle->first);
        response->status_cursor = needs_check ? eb_find_bus(cycle->first) : EB_NULL;
        
        /* Claim response address */
        response->address = aux->rba;
        aux->rba = 0x8000 | (aux->rba + 2);
        
        /* Chain it for response processing in FIFO order */
        response->next = socket->last_response;
        socket->last_response = responsep;
      }
      
      /* Update end pointer */
      cptr = wptr;
    }
  }
  
  /* Refresh pointer derferences */
  device = EB_DEVICE(devicep);
  transport = EB_TRANSPORT(device->transport);
  link = EB_LINK(device->link);
  
  if (mtu == 0) {
    (*eb_transports[transport->link_type].send)(transport, link, &buffer[0], wptr - &buffer[0]);
  } else {
    if (wptr != &buffer[header_alignment])
      (*eb_transports[transport->link_type].send)(transport, link, &buffer[0], wptr - &buffer[0]);
  }
  
  device->ready = EB_NULL;
}
