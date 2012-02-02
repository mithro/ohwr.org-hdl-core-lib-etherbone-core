/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone socket read/writes.
 */

#define ETHERBONE_IMPL

#include "socket.h"
#include "../memory/memory.h"

void eb_socket_write(struct eb_socket* socket, int config, eb_width_t widths, eb_address_t addr, eb_data_t value, uint64_t* error) {
  if (config) {
    /* Write to config space */
    // !!!
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
    // !!!
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
