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

eb_status_t eb_socket_attach(eb_socket_t socketp, const struct eb_handler* handler) {
  eb_handler_address_t addressp, i;
  eb_handler_callback_t callbackp;
  struct eb_socket* socket;
  struct eb_handler_address* address;
  struct eb_handler_callback* callback;
  eb_address_t new_first, new_last;
  eb_address_t dev_first, dev_last;
  
  /* Get memory */
  addressp = eb_new_handler_address();
  if (addressp == EB_NULL)
    return EB_OOM;
  
  callbackp = eb_new_handler_callback();
  if (callbackp == EB_NULL) {
    eb_free_handler_address(addressp);
    return EB_OOM;
  }
  
  new_first = handler->device->sdb_component.addr_first;
  new_last  = handler->device->sdb_component.addr_last;
  
  /* Is the address range supported by our bus size? */
  if (new_first != handler->device->sdb_component.addr_first || new_last != handler->device->sdb_component.addr_last)
    return EB_ADDRESS;
  
  /* Does it overlap out reserved memory range? */
  if (new_first < 0x4000) return EB_ADDRESS;
  
  socket = EB_SOCKET(socketp);
  
  /* See if it overlaps other devices */
  for (i = socket->first_handler; i != EB_NULL; i = address->next) {
    address = EB_HANDLER_ADDRESS(i);
    
    dev_first = address->device->sdb_component.addr_first;
    dev_last  = address->device->sdb_component.addr_last;
    
    /* Do the address ranges overlap? */
    if (new_first <= dev_last && dev_first <= new_last) {
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

eb_status_t eb_socket_detach(eb_socket_t socketp, const struct sdb_device* device) {
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
