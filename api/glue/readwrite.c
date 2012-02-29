/** @file readwrite.c
 *  @brief Process incoming Etherbone read/writes.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  All methods can assume eb_width_refined.
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

#include "socket.h"
#include "cycle.h"
#include "operation.h"
#include "../memory/memory.h"
#include "../format/bigendian.h"

void eb_socket_write_config(eb_socket_t socketp, eb_width_t widths, eb_address_t addr, eb_data_t value) {
  /* Write to config space => write-back */
  int fail;
  eb_response_t *responsepp;
  eb_response_t responsep;
  eb_operation_t operationp;
  eb_cycle_t cyclep;
  struct eb_socket* socket;
  struct eb_response* response;
  struct eb_operation* operation;
  struct eb_cycle* cycle;
  
  /* Walk the response queue */
  socket = EB_SOCKET(socketp);
  responsepp = &socket->first_response;
  while (1) {
    if ((responsep = *responsepp) == EB_NULL) {
      *responsepp = responsep = eb_socket_flip_last(socket);
      if (responsep == EB_NULL) return; /* No matching response record */
    }
    response = EB_RESPONSE(responsep);
    
    if (response->address == (addr & 0xFFFE)) break;
    responsepp = &response->next;
  }
  
  /* Now, process the write */
  if ((addr & 1) == 0) {
    /* A write_cursor update */
    if (response->write_cursor == EB_NULL) {
      fail = 1;
    } else {
      fail = 0;
      
      operation = EB_OPERATION(response->write_cursor);
      
      if ((operation->flags & EB_OP_MASK) == EB_OP_READ_PTR) {
        *operation->un_value.read_destination = value;
      } else {
        operation->un_value.read_value = value;
      }
      
      response->write_cursor = eb_find_read(operation->next);
    }
  } else {
    /* An error status update */
    int i, ops, maxops;
    
    /* Maximum feed-back from this read */
    maxops = (widths & EB_DATAX) * 8;
    
    /* Count how many operations need a status update */
    ops = 0;
    for (operationp = response->status_cursor; operationp != EB_NULL; operationp = operation->next) {
      operation = EB_OPERATION(operationp);
      if ((operation->flags & EB_OP_CFG_SPACE) != 0) continue; /* skip config ops */
      if (++ops == maxops) break;
    }
    
    fail = (ops == 0); /* No reason to get error status if no ops! */
    
    i = ops-1;
    for (operationp = response->status_cursor; i >= 0; operationp = operation->next) {
      operation = EB_OPERATION(operationp);
      if ((operation->flags & EB_OP_CFG_SPACE) != 0) continue;
      operation->flags |= EB_OP_ERROR * ((value >> i) & 1);
      --i;
    }
    
    /* Update the cursor... skipping cfg space operations */
    response->status_cursor = eb_find_bus(operationp);
  }
  
  /* Check for response completion */
  if (fail || (response->write_cursor == EB_NULL && response->status_cursor == EB_NULL)) {
    cyclep = response->cycle;
    cycle = EB_CYCLE(cyclep);

    *responsepp = response->next;
    
    if (cycle->callback)
      (*cycle->callback)(cycle->user_data, cycle->un_ops.first, fail?EB_FAIL:EB_OK);

    eb_cycle_destroy(cyclep);
    eb_free_cycle(cyclep);
    eb_free_response(responsep);
  }
}

void eb_socket_write(eb_socket_t socketp, eb_width_t widths, eb_address_t addr, eb_data_t value, uint64_t* error) {
  /* Write to local WB bus */
  eb_handler_address_t addressp;
  struct eb_handler_address* address;
  struct eb_socket* socket;
  eb_address_t start, end;
  int fail;
  
  /* SDWB address? It's read only ... */
  if (addr < 0x4000) {
    *error = (*error << 1) | 1;
    return;
  }
  
  socket = EB_SOCKET(socketp);
  for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
    address = EB_HANDLER_ADDRESS(addressp);
    start = address->device->hdl_base;
    end = start + (eb_address_t)address->device->hdl_size - 1;
    if (start <= addr && addr <= end) break;
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

eb_data_t eb_socket_read_config(eb_socket_t socketp, eb_width_t widths, eb_address_t addr, uint64_t error) {
  /* We only support reading from the error shift register so far */
  eb_data_t out;
  int len;
  uint8_t buf[16] = {
    error >> 56, error >> 48, error >> 40, error >> 32,
    error >> 24, error >> 16, error >>  8, error >>  0,
    0, 0, 0, 0, 0, 0, 0, 0
  };
  
  len = (widths & EB_DATAX);
  
  /* Read out of bounds */
  if (addr >= 8) return 0;
  
  /* Read memory */
  out = 0;
  while (len--) {
    out <<= 8;
    out |= buf[addr++];
  }
  
  return out;
}

eb_data_t eb_socket_read(eb_socket_t socketp, eb_width_t widths, eb_address_t addr, uint64_t* error) {
  /* Read to local WB bus */
  eb_data_t out;
  eb_handler_address_t addressp;
  struct eb_handler_address* address;
  struct eb_socket* socket;
  eb_address_t start, end;
  int fail;
  
  /* SDWB address? */
  if (addr < 0x4000) {
    *error = (*error << 1);
    return eb_sdwb(socketp, widths, addr);
  }
  
  socket = EB_SOCKET(socketp);
  for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
    address = EB_HANDLER_ADDRESS(addressp);
    start = address->device->hdl_base;
    end = start + (eb_address_t)address->device->hdl_size - 1;
    if (start <= addr && addr <= end) break;
  }
  
  if (addressp == EB_NULL) {
    /* Segfault => shift in an error */
    out = 0;
    fail = 1;
  } else {
    struct eb_handler_callback* callback = EB_HANDLER_CALLBACK(address->callback);
    if (callback->read) {
      /* Run the virtual device */
      fail = (*callback->read)(callback->data, addr, widths, &out) != EB_OK;
    } else {
      /* Not readable => error */
      out = 0;
      fail = 1;
    }
  }
  
  /* Update the error shift status */
  *error = (*error << 1) | fail;
  return out;
}
