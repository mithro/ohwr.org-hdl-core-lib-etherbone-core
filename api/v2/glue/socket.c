/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone socket data structure.
 */

#define ETHERBONE_IMPL

#include "socket.h"
#include "device.h"
#include "cycle.h"
#include "widths.h"
#include "../transport/transport.h"
#include "../memory/memory.h"
#include "../format/format.h"

const char* eb_status(eb_status_t code) {
  switch (code) {
  case EB_OK:       return "success";
  case EB_FAIL:     return "system failure";
  case EB_ADDRESS:  return "invalid address";
  case EB_WIDTH:    return "bus width mismatch";
  case EB_OVERFLOW: return "cycle length overflow";
  case EB_BUSY:     return "resource busy";
  case EB_OOM:      return "out of memory";
  default:          return "unknown Etherbone error code";
  }
}

eb_status_t eb_socket_open(int port, eb_width_t supported_widths, eb_socket_t* result) {
  eb_socket_t socketp;
  eb_socket_aux_t auxp;
  eb_transport_t transportp;
  struct eb_transport* transport;
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  eb_status_t status;
  uint8_t link_type;
  
  /* Constrain widths to those supported by compilation */
  if (sizeof(eb_data_t) < 8) supported_widths &= ~EB_DATA64;
  if (sizeof(eb_data_t) < 4) supported_widths &= ~EB_DATA32;
  if (sizeof(eb_data_t) < 2) supported_widths &= ~EB_DATA16;
  if (sizeof(eb_address_t) < 8) supported_widths &= ~EB_ADDR64;
  if (sizeof(eb_address_t) < 4) supported_widths &= ~EB_ADDR32;
  if (sizeof(eb_address_t) < 2) supported_widths &= ~EB_ADDR16;
  
  /* Is the width choice valid? */
  if (eb_width_possible(supported_widths) == 0)
    return EB_WIDTH;
  
  /* Allocate the soocket */
  socketp = eb_new_socket();
  if (socketp == EB_NULL) {
    *result = EB_NULL;
    return EB_OOM;
  }
  auxp = eb_new_socket_aux();
  if (auxp == EB_NULL) {
    *result = EB_NULL;
    eb_free_socket(socketp);
    return EB_OOM;
  }
  
  socket = EB_SOCKET(socketp);
  socket->first_device = EB_NULL;
  socket->first_handler = EB_NULL;
  socket->first_response = EB_NULL;
  socket->last_response = EB_NULL;
  socket->widths = supported_widths;
  socket->aux = auxp;
  
  aux = EB_SOCKET_AUX(auxp);
  aux->time_cache = 0;
  aux->first_transport = EB_NULL;
  
  for (link_type = 0; link_type != eb_transport_size; ++link_type) {
    transportp = eb_new_transport();
    
    /* Stop with OOM error */
    if (transportp == EB_NULL) {
      status = EB_OOM;
      break;
    }
    
    transport = EB_TRANSPORT(transportp);
    status = eb_transports[link_type].open(transport, port);
    
    /* Skip this transport */
    if (status == EB_ADDRESS) {
      eb_free_transport(transportp);
      continue;
    }
    
    /* Stop if some other problem */
    if (status != EB_OK) break;
    
    transport->next = aux->first_transport;
    transport->link_type = link_type;
    aux->first_transport = transportp;
  }
  
  if (link_type != eb_transport_size) {
    eb_socket_close(socketp);
    return status;
  }
  
  *result = socketp;
  return EB_OK;
}

eb_response_t eb_socket_flip_last(struct eb_socket* socket) {
  struct eb_response* i;
  eb_response_t ip, prev, next;
  
  prev = EB_NULL;
  for (ip = socket->last_response; ip != EB_NULL; ip = next) {
    i = EB_RESPONSE(ip);
    next = i->next;
    i->next = prev;
    prev = ip;
  }
  
  socket->last_response = EB_NULL;
  return prev;
}

eb_status_t eb_socket_close(eb_socket_t socketp) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_handler_address* handler;
  struct eb_response* response;
  struct eb_cycle* cycle;
  struct eb_transport* transport;
  eb_transport_t transportp, next_transportp;
  eb_response_t tmp;
  eb_handler_address_t i, next;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  if (socket->first_device != EB_NULL)
    return EB_BUSY;
  
  /* Cancel all callbacks */
  while ((tmp = socket->first_response) != EB_NULL) {
    response = EB_RESPONSE(tmp);
    
    if (response->next == EB_NULL) {
      socket->first_response = eb_socket_flip_last(socket);
    } else {
      socket->first_response = response->next;
    }
    
    /* Report the cycle callback */
    cycle = EB_CYCLE(response->cycle);
    (*cycle->callback)(cycle->user_data, cycle->first, EB_FAIL);
    
    /* Free associated memory */
    eb_cycle_destroy(response->cycle);
    eb_free_cycle(response->cycle);
    eb_free_response(tmp);
  }
  
  /* Flush handlers */
  for (i = socket->first_handler; i != EB_NULL; i = next) {
    handler = EB_HANDLER_ADDRESS(i);
    next = handler->next;
    
    eb_free_handler_callback(handler->callback);
    eb_free_handler_address(i);
  }
  
  
  for (transportp = aux->first_transport; transportp != EB_NULL; transportp = next_transportp) {
    transport = EB_TRANSPORT(transportp);
    next_transportp = transport->next;
    eb_transports[transport->link_type].close(transport);
  }
  
  eb_free_socket(socketp);
  return EB_OK;
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

void eb_socket_descriptor(eb_socket_t socketp, eb_user_data_t user, eb_descriptor_callback_t cb) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_link* link;
  eb_device_t devicep;
  eb_transport_t transportp;
  eb_link_t linkp;
  eb_descriptor_t fd;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  
  /* Add all the transports */
  for (transportp = aux->first_transport; transportp != EB_NULL; transportp = transport->next) {
    transport = EB_TRANSPORT(transportp);
    
    fd = eb_transports[transport->link_type].fdes(transport, 0);
    (*cb)(user, fd);
  }
  
  /* Add all the sockets to the listen set */
  for (devicep = socket->first_device; devicep != EB_NULL; devicep = device->next) {
    device = EB_DEVICE(devicep);
    
    linkp = device->link;
    if (linkp != EB_NULL) {
      link = EB_LINK(linkp);
      transportp = device->transport;
      transport = EB_TRANSPORT(transportp);
      
      fd = eb_transports[transport->link_type].fdes(transport, link);
      (*cb)(user, fd);
    }
  }
}

void eb_socket_settime(eb_socket_t socketp, uint32_t now) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  
  aux->time_cache = now;
}

uint32_t eb_socket_timeout(eb_socket_t socketp) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_response* response;
  uint16_t udelta;
  int16_t sdelta;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  
  /* Find the first timeout */
  if (socket->first_response == EB_NULL)
    socket->first_response = eb_socket_flip_last(socket);
  
  /* Determine how long until deadline expires */ 
  if (socket->first_response != EB_NULL) {
    response = EB_RESPONSE(socket->first_response);
    
    udelta = response->deadline - ((uint16_t)aux->time_cache);
    sdelta = udelta; /* Sign conversion */
    return aux->time_cache + sdelta;
  } else {
    return aux->time_cache + 600; /* No timeout? Run poll in 10 minutes. */
  }
}

eb_status_t eb_socket_poll(eb_socket_t socketp) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_response* response;
  struct eb_cycle* cycle;
  eb_device_t devicep;
  eb_transport_t transportp;
  eb_response_t responsep;
  eb_cycle_t cyclep;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  
  /* Step 1. Kill any expired timeouts */
  while (eb_socket_timeout(socketp) <= aux->time_cache) {
    /* Kill first */
    responsep = socket->first_response;
    response = EB_RESPONSE(responsep);
    
    cyclep = response->cycle;
    cycle = EB_CYCLE(cyclep);
    
    (*cycle->callback)(cycle->user_data, cycle->first, EB_TIMEOUT);
    
    socket->first_response = response->next;
    eb_cycle_destroy(cyclep);
    eb_free_cycle(cyclep);
    eb_free_response(responsep);
  }
  
  /* Step 2. Check all devices */
  
  /* Poll all the transports */
  for (transportp = aux->first_transport; transportp != EB_NULL; transportp = transport->next) {
    transport = EB_TRANSPORT(transportp);
    eb_device_slave(socket, transport, EB_NULL, 0);
  }
  
  /* Add all the sockets to the listen set */
  for (devicep = socket->first_device; devicep != EB_NULL; devicep = device->next) {
    device = EB_DEVICE(devicep);
    
    transportp = device->transport;
    transport = EB_TRANSPORT(transportp);
    
    eb_device_slave(socket, transport, devicep, device);
  }
  
  return EB_OK;
}
