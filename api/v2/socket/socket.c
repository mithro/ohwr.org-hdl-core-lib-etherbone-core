/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone socket data structure.
 */

#include "socket.h"
#include "../memory/memory.h"

eb_status_t eb_socket_open(int port, eb_flags_t flags, eb_width_t supported_addr_widths, eb_width_t supported_port_widths, eb_socket_t* result) {
  eb_socket_t socketp;
  struct eb_socket* socket;
  
  /* Allocate the soocket */
  socketp = eb_new_socket();
  if (socketp == EB_NULL) {
    *result = EB_NULL;
    return -EB_OOM;
  }
  
  socket = EB_SOCKET(socketp);
  socket->first_device = EB_NULL;
  socket->first_handler = EB_NULL;
  socket->first_response = EB_NULL;
  socket->last_response = EB_NULL;
  socket->widths = supported_addr_widths << 4 | supported_port_widths;
  
  /* !!! open links */
  socket->links = 0;
  
  *result = socketp;
  return EB_OK;
}

eb_status_t eb_socket_close(eb_socket_t socketp) {
  struct eb_socket* socket;
  struct eb_handler_address* handler;
  struct eb_response* response;
  struct eb_cycle* cycle;
  eb_response_t tmp;
  eb_handler_address_t i;
  
  socket = EB_SOCKET(socketp);
  if (socket->first_device != EB_NULL)
    return EB_BUSY;
  
  /* Cancel all callbacks */
  while ((tmp = socket->first_response) != EB_NULL) {
    response = EB_RESPONSE(tmp);
    socket->first_response = response->next;
    
    /* Report the cycle callback */
    cycle = EB_CYCLE(response->cycle);
    (*cycle->callback)(cycle->user_data, EB_FAIL);
    
    /* Free associated memory */
    eb_cycle_abort(response->cycle);
    eb_free_cycle(response->cycle);
    
    eb_free_response(tmp);
  }
  while ((tmp = socket->last_response) != EB_NULL) {
    response = EB_RESPONSE(tmp);
    socket->last_response = response->next;
    
    /* Report the cycle callback */
    cycle = EB_CYCLE(response->cycle);
    (*cycle->callback)(cycle->user_data, EB_FAIL);
    
    /* Free associated memory */
    eb_cycle_abort(response->cycle);
    eb_free_cycle(response->cycle);
    
    eb_free_response(tmp);
  }
  
  /* Flush handlers */
  for (i = socket->first_handler; i != EB_NULL; i = handler->next) {
    handler = EB_HANDLER_ADDRESS(i);
    eb_free_handler_callback(handler->callback);
    eb_free_handler_address(i);
  }
  
  /* !!! close links */
  
  eb_free_socket(socketp);
  return EB_OK;
}

eb_status_t eb_socket_poll(eb_socket_t socket) {
  /* !!! */
  return EB_OK;
}

int eb_socket_block(eb_socket_t socket, int timeout_us) {
  /* !!! */
  return timeout_us;
}

eb_status_t eb_socket_attach(eb_socket_t socketp, eb_handler_t handler) {
  eb_handler_address_t addressp, i;
  eb_handler_callback_t callbackp;
  struct eb_socket* socket;
  struct eb_handler_address* address;
  struct eb_handler_callback* callback;
  
  socket = EB_SOCKET(socketp);
  
  /* See if it overlaps other devices */
  for (i = socket->first_handler; i != EB_NULL; i = address->next) {
    address = EB_HANDLER_ADDRESS(i);
    if (((address->base ^ handler->base) & ~(address->mask | handler->mask)) == 0)
      return EB_ADDRESS;
  }
  
  /* Get memory */
  addressp = eb_new_handler_address();
  if (addressp == EB_NULL)
    return EB_OOM;
  
  callbackp = eb_new_handler_callback();
  if (callbackp == EB_NULL) {
    eb_free_handler_address(addressp);
    return EB_OOM;
  }
  
  /* Insert the new virtual device */
  address = EB_HANDLER_ADDRESS(addressp);
  callback = EB_HANDLER_CALLBACK(callbackp);
  
  address->base = handler->base;
  address->mask = handler->mask;
  address->callback = callbackp;
  callback->data = handler->data;
  callback->read = handler->read;
  callback->write = handler->write;
  
  address->next = socket->first_handler;
  socket->first_handler = addressp;
  return EB_OK;
}

eb_status_t eb_socket_detach(eb_socket_t socketp, eb_address_t target_address) {
  eb_handler_address_t i, *ptr;
  struct eb_socket* socket;
  struct eb_handler_address* address;
  
  socket = EB_SOCKET(socketp);
  
  /* Find the device */
  for (ptr = &socket->first_handler; (i = *ptr) != EB_NULL; ptr = &address->next) {
    address = EB_HANDLER_ADDRESS(i);
    if (address->base == target_address)
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

