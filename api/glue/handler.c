/** @file socket.c
 *  @brief Implement the Etherbone socket data structure.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  This data structure does not deal directly with IO.
 *  For actual transport-layer sockets, see transport/.
 *  For reading/writing of payload, see format/.
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

#include "../memory/memory.h"
#include "socket.h"
#include "handler.h"

eb_status_t eb_socket_attach(eb_socket_t socketp, eb_handler_t handler) {
  eb_handler_address_t addressp, i;
  eb_handler_callback_t callbackp;
  struct eb_socket* socket;
  struct eb_handler_address* address;
  struct eb_handler_callback* callback;
  uint64_t new_start, new_end;
  uint64_t dev_start, dev_end;
  
  /* Get memory */
  addressp = eb_new_handler_address();
  if (addressp == EB_NULL)
    return EB_OOM;
  
  callbackp = eb_new_handler_callback();
  if (callbackp == EB_NULL) {
    eb_free_handler_address(addressp);
    return EB_OOM;
  }
  
  new_start = handler->device->hdl_base;
  new_end = new_start + handler->device->hdl_size;
  
  socket = EB_SOCKET(socketp);
  
  /* See if it overlaps other devices */
  for (i = socket->first_handler; i != EB_NULL; i = address->next) {
    address = EB_HANDLER_ADDRESS(i);
    
    dev_start = address->device->hdl_base;
    dev_end = dev_start + address->device->hdl_base;
    
    /* Do the address ranges overlap? */
    if (new_start <= dev_end && dev_start <= new_end) {
      eb_free_handler_callback(callbackp);
      eb_free_handler_address(addressp);
      return EB_ADDRESS;
    }
  }
  
  /* Insert the new virtual device */
  address = EB_HANDLER_ADDRESS(addressp);
  callback = EB_HANDLER_CALLBACK(callbackp);
  
  address->device = handler->device;
  address->callback = callbackp;
  callback->data = handler->data;
  callback->read = handler->read;
  callback->write = handler->write;
  
  address->next = socket->first_handler;
  socket->first_handler = addressp;
  return EB_OK;
}

eb_status_t eb_socket_detach(eb_socket_t socketp, sdwb_device_descriptor_t device) {
  eb_handler_address_t i, *ptr;
  struct eb_socket* socket;
  struct eb_handler_address* address;
  
  socket = EB_SOCKET(socketp);
  
  /* Find the device */
  for (ptr = &socket->first_handler; (i = *ptr) != EB_NULL; ptr = &address->next) {
    address = EB_HANDLER_ADDRESS(i);
    if (address->device == device)
      break;
  }
  
  /* No device found? */
  if (i == EB_NULL)
    return EB_ADDRESS;
  
  /* Remove it */
  *ptr = address->next;
  eb_free_handler_callback(address->callback);
  eb_free_handler_address(i);
  return EB_OK;
}

