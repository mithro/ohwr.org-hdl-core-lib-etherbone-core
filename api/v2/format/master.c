/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * Format an out-going Etherbone packet
 */

#define ETHERBONE_IMPL

#include <limits.h>

#include "../glue/operation.h"
#include "../glue/cycle.h"
#include "../glue/device.h"
#include "../glue/socket.h"
#include "../transport/transport.h"
#include "../memory/memory.h"

void eb_device_flush(eb_device_t devicep) {
  struct eb_device* device;
  struct eb_link* link;
  struct eb_transport* transport;
  struct eb_cycle* cycle;
  struct eb_response* response;
  eb_cycle_t cyclep, nextp;
  eb_response_t resopnsep;
  eb_widht_t biggest, data;
  uint8_t buffer[4104]; /* Big enough for an entire record */
  uint8_t * wptr, * cptr;
  int alignment, record_alignment, stride, mtu;
  
  device = EB_DEVICE(devicep);
  socket = EB_SOCKET(device->socket);
  link = EB_LINK(device->link);
  transport = EB_LINK(device->transport);
  
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
  stride = 1;
  stride += (data >= EB_DATA16)*1;
  stride += (data >= EB_DATA32)*2;
  stride += (data >= EB_DATA64)*4;
  
  /* Non-streaming sockets need a header */
  mtu = eb_transports[transport->link_type].mtu;
  if (mtu != 0) {
    memset(&buffer[0], 0, record_alignment);
    buffer[0] = 0x4E;
    buffer[1] = 0x6F;
    buffer[2] = 0x10; /* V1. no probe. */
    buffer[3] = device->widths;
    wptr = &buffer[record_alignment];
  } else {
    wptr = &buffer[0];
  }
  
  for (cyclep = device->ready; cyclep != EB_NULL; cyclep = nextp) {
    struct eb_operation* operation;
    struct eb_operation* scan;
    eb_operation_t operationp;
    eb_operation_t scanp;
    int needs_check;
    int ops, maxops;
  
    cycle = EB_CYCLE(cyclep);
    nextp = cycle->next;
    
    /* Deal with OOM cases */
    if (cycle->dead == cyclep) {
      (*cycle->callback)(cycle->user_data, EB_NULL, EB_OOM);
      eb_free_cycle(cyclep);
      continue;
    }
    
    /* Was the cycle a no-op? */
    if (cycle->first == EB_NULL) {
      (*cycle->callback)(cycle->user_data, EB_NULL, EB_OK);
      eb_free_cycle(cyclep);
      continue;
    }
    
    /* Record to hook it into socket */
    responsep = eb_new_response();
    if (responsep == EB_NULL) {
      (*cycle->callback)(cycle->user_data, EB_NULL, EB_OOM);
      eb_cycle_destroy(cyclep);
      eb_free_cycle(cyclep);
      continue;
    }
    
    needs_check = (cycle->first->flags & EB_OP_CHECKED) != 0;
    if (needs_check) {
      maxops = stride * 8;
    } else {
      maxops = INT_MAX;
    }
    
    operationp = cycle->first;
    
    /* Begin formatting the packet into records */
    ops = 0;
    while (operationp != EB_NULL) {
      int wcount, rcount, total, length, fifo;
      eb_address_t bwa;
      eb_operation_flags_t cfg;
      
      scanp = operationp;
      
      /* First pack writes into a record, if any */
      if (ops >= maxops ||
          /* scanp == EB_NULL || */ /* implied by outer while loop */
          ((scan = EB_OPERATION(scanp))->flags & EB_OP_MASK) != EB_OP_WRITE) {
        /* No writes in this record */
        wcount = 0;
      } else {
        cfg = scan->flags & EB_OP_CFG_SPACE;
        bwa = scan->address;
        scanp = scan->next;
        
        if (cfg == 0) ++ops;
        
        /* How many writes can we chain? must be either FIFO or sequential in same address space */
        if (ops >= maxops ||
            scanp == EB_NULL ||
            ((scan = EB_OPERATION(scanp))->flags & EB_OP_MASK) != EB_OP_WRITE ||
            (scan->flags & EB_OP_CFG_SPACE) != cfg) {
          /* Only a single write */
          fifo = 0;
          wcount = 1;
        } else {
          /* Consider if FIFO or sequential work */
          if (scan->address == bwa) {
            /* FIFO -- count how many ops we can chain */
            fifo = 1;
            wcount = 2;
            if (cfg == 0) ++ops;
            
            for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
              scan = EB_OPERATION(scanp);
              if (scan->address != bwa) break;
              if ((scan->flags & EB_OP_CFG_SPACE) != cfg) break;
              if (wcount >= 255) break;
              if (ops >= maxops) break;
              if (cfg == 0) ++ops;
              ++wcount;
            }
          } else if (scan->address == (bwa += stride)) {
            /* Sequential */
            fifo = 0;
            wcount = 2;
            if (cfg == 0) ++ops;
            
            for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
              scan = EB_OPERATION(scanp);
              if (scan->address != (bwa += stride)) break;
              if ((scan->flags & EB_OP_CFG_SPACE) != cfg) break;
              if (wcount >= 255) break;
              if (ops >= maxops) break;
              if (cfg == 0) ++ops;
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
          /* scan is definitely initialized if the prior two tests fail */
          (scan->flags & EB_OP_MASK) == EB_OP_WRITE) {
        /* No reads in this record */
        rcount = 0;
      } else {
        cfg = scan->flags & EB_OP_CFG_SPACE;
        if (cfg == 0) ++ops;
        
        rcount = 1;
        for (scanp = scan->next; scanp != EB_NULL; scanp = scan->next) {
          scan = EB_OPERATION(scanp);
          if ((scan->flags & EB_OP_CFG_SPACE) != cfg) break;
          if (rcount >= 255) break;
          if (ops >= maxops) break;
          if (cfg == 0) ++ops;
          ++rcount;
        }
      }
      
      /* Compute total request length */
      total = (wcount > 0) + wcount;
      if (rcount == 0 && ops >= maxops) {
        /* Insert error-status read */
        total += 2;
      } else {
        total += (rcount > 0) + rcount;
      }
      
      length = record_alignment + total*alignment;
      
      /* Ensure sufficient buffer space */
      if (length > &buffer[sizeof(buffer)] - wptr) {
        if (mtu == 0) {
          /* Overflow in a streaming device => flush and continue */
          (*eb_transports[transport->link_type].send)(transport, link, &buffer[0], wptr - &buffer[0]);
          wptr = &buffer[0];
        } else {
          /* Overflow in a packet-based device, send any previous cycles and keep current */
          
          
          /* Test for cycle overflow of MTU */
          if (...) {
            /* Blow up in the face of the user */
            (*cycle->callback)(cycle->user_data, cycle->first, EB_OVERFLOW);
            eb_cycle_destroy(cyclep);
            eb_free_cycle(cyclep);
            eb_free_response(responsep);
            break;
          } 
        }
      }
      
      /* Start by preparting the header */
      memset(wptr, 0, record_alignment);
      wptr[0] = 0;
    }
    
    if (operationp == EB_NULL) {
      response = EB_RESPONSE(responsep);
      
      /* Setup a response */
      response->address = 0x8110; // !!!
      response->deadline = 0 + 5; // !!! gettimeofday AGAIN!?!?  => implement socket-level time cache
      response->cycle = cyclep;
      response->write_cursor = operationp;
      response->status_cursor = needs_check ? operationp : EB_NULL;
      
      /* Chain it for response processing in FIFO order */
      response->next = cycle->last_response;
      cycle->last_response = responsep;
    }
  }
  
  device->ready = EB_NULL;
}
