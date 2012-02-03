/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone socket read/writes.
 */

#define ETHERBONE_IMPL

#include "socket.h"
#include "cycle.h"
#include "../memory/memory.h"
#include "../format/bigendian.h"

void eb_socket_write(struct eb_socket* socket, int config, eb_width_t widths, eb_address_t addr, eb_data_t value, uint64_t* error) {
  if (config) {
    /* Write to config space => write-back */
    int fail;
    eb_response_t *responsepp;
    eb_response_t responsep;
    eb_operation_t operationp;
    eb_cycle_t cyclep;
    struct eb_response* response;
    struct eb_operation* operation;
    struct eb_cycle* cycle;
    
    /* Walk the response queue */
    responsepp = &socket->first_response;
    while (1) {
      if ((responsep = *responsepp) == EB_NULL) {
        *responsepp = responsep = eb_socket_flip_last(socket);
        if (responsep == EB_NULL) break;
      }
      response = EB_RESPONSE(responsep);
      
      if (response->address == (addr & 0xFFFE)) break;
      responsepp = &response->next;
    }
    
    if (responsep == EB_NULL) return; /* No matching response record */
    
    /* Now, process the write */
    if ((addr & 1) == 0) {
      /* A write_cursor update */
      if (response->write_cursor == EB_NULL) {
        fail = 1;
      } else {
        operation = EB_OPERATION(response->write_cursor);
        
        if ((operation->flags & EB_OP_READ_PTR) != 0) {
          *operation->read_destination = value;
        } else {
          operation->read_value = value;
        }
        
        response->write_cursor = operation->next;
      }
    } else {
      /* An error status update */
      int i, ops, maxops;
      
      /* Maximum feed-back from this read */
      switch (widths & EB_DATAX) {
        case EB_DATA8:  maxops =  8; break;
        case EB_DATA16: maxops = 16; break;
        case EB_DATA32: maxops = 32; break;
        default:        maxops = 64; break;
      }
      
      /* Count how many operations need a status update */
      ops = 0;
      for (operationp = response->status_cursor; operationp != EB_NULL; operationp = operation->next) {
        operation = EB_OPERATION(operationp);
        if ((operations->flags & EP_OP_CFG_SPACE) != 0) continue;
        if (++ops == maxops) break;
      }
      
      if (ops == 0) fail = 1; /* No reason to get error status if no ops! */
      
      i = opts-1;
      for (operationp = response->status_cursor; i >= 0; operationp = operation->next) {
        operation = EB_OPERATION(operationp);
        if ((operations->flags & EP_OP_CFG_SPACE) != 0) continue;
        operation->flags |= EB_OP_ERROR * ((value >> i) & 1);
        --i;
      }
      
      /* Update the cursor... skipping cfg space operations */
      for (; operationp != EB_NULL; operationp = operation->next) {
        operation = EB_OPERATION(operationp);
        if ((operation->flags & EB_OP_CFG_SPACE) != 0) break;
      }
      response->status_cursor = operationp;
    }
    
    /* Check for response completion */
    if (fail || (response->write_cursor == EB_NULL && response->status_cursor == EB_NULL)) {
      cyclep = response->cycle;
      cycle = EB_CYCLE(cyclep);
      
      (*cycle->callback)(cycle->user_data, cycle->first, fail?EB_FAIL:EB_OK);

      *responsepp = response->next;
      eb_cycle_destroy(cyclep);
      eb_free_cycle(cyclep);
      eb_free_response(responsep);
    }
  } else {
    /* Write to local WB bus */
    eb_handler_address_t addressp;
    struct eb_handler_address* address;
    int fail;
    
    for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
      address = EB_HANDLER_ADDRESS(addressp);
      if (((addr ^ address->base) & (~address->mask)) == 0) break;
    }
    
    if (addressp == EB_NULL) {
      /* Segfault => shift in an error */
      fail = 1;
    } else {
      struct eb_handler_callback* callback = EB_HANDLER_CALLBACK(address->callback);
      if (callback->write) {
        /* Run the virtual device */
        fail = (*callback->write)(callback->data, addr, widths, value) != EB_OK;
      } else {
        /* Not writeable => error */
        fail = 1;
      }
    }
    
    /* Update the error shift status */
    *error = (*error << 1) | fail;
  }
}

eb_data_t eb_socket_read(struct eb_socket* socket, int config, eb_width_t widths, eb_address_t addr, uint64_t* error) {
  eb_data_t out;
  
  if (config) {
    /* We only support reading from the error shift register so far */
    int len;
    uint8_t buf[16] = {
      *error >> 56, *error >> 48, *error >> 40, *error >> 32,
      *error >> 24, *error >> 16, *error >>  8, *error >>  0,
      0, 0, 0, 0, 0, 0, 0, 0
    };
    
    switch (widths & EB_DATAX) {
    case EB_DATA8:  len = 1; break;
    case EB_DATA16: len = 2; break;
    case EB_DATA32: len = 4; break;
    default:        len = 8; break;
    }
    
    /* Read out of bounds */
    if (addr >= 8) return 0;
    
    /* Read memory */
    out = 0;
    while (len--) {
      out <<= 8;
      out |= buf[addr++];
    }
  } else {
    /* Read to local WB bus */
    eb_handler_address_t addressp;
    struct eb_handler_address* address;
    int fail;
    
    for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
      address = EB_HANDLER_ADDRESS(addressp);
      if (((addr ^ address->base) & (~address->mask)) == 0) break;
    }
    
    if (addressp == EB_NULL) {
      /* Segfault => shift in an error */
      fail = 1;
    } else {
      struct eb_handler_callback* callback = EB_HANDLER_CALLBACK(address->callback);
      if (callback->read) {
        /* Run the virtual device */
        fail = (*callback->read)(callback->data, addr, widths, &out) != EB_OK;
      } else {
        /* Not readable => error */
        fail = 1;
      }
    }
    
    /* Update the error shift status */
    *error = (*error << 1) | fail;
  }
  
  return out;
}
