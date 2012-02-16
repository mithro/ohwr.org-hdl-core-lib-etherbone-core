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
  case EB_TIMEOUT:  return "timeout";
  case EB_OOM:      return "out of memory";
  default:          return "unknown Etherbone error code";
  }
}

eb_status_t eb_socket_open(const char* port, eb_width_t supported_widths, eb_socket_t* result) {
  eb_socket_t socketp;
  eb_socket_aux_t auxp;
  eb_transport_t transportp, first_transport;
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
  
  /* Allocate the transports */
  status = EB_OK;
  first_transport = EB_NULL;
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
    
    transport->next = first_transport;
    transport->link_type = link_type;
    first_transport = transportp;
  }
  
  /* Allocation is finished, dereference the pointers */
  
  socket = EB_SOCKET(socketp);
  socket->first_device = EB_NULL;
  socket->first_handler = EB_NULL;
  socket->first_response = EB_NULL;
  socket->last_response = EB_NULL;
  socket->widths = supported_widths;
  socket->aux = auxp;
  
  aux = EB_SOCKET_AUX(auxp);
  aux->time_cache = 0;
  aux->rba = 0x8000;
  aux->first_transport = first_transport;
  
  if (link_type != eb_transport_size) {
    eb_socket_close(socketp);
    return status;
  }
  
  *result = socketp;
  return status;
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
    if (cycle->callback)
      (*cycle->callback)(cycle->user_data, cycle->first, EB_FAIL); /* invalidate: socket response cycle */
    
    socket = EB_SOCKET(socketp);
    response = EB_RESPONSE(tmp);
    
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
  
  aux = EB_SOCKET_AUX(socket->aux);
  
  for (transportp = aux->first_transport; transportp != EB_NULL; transportp = next_transportp) {
    transport = EB_TRANSPORT(transportp);
    next_transportp = transport->next;
    eb_transports[transport->link_type].close(transport);
  }
  
  eb_free_socket(socketp);
  return EB_OK;
}

void eb_socket_descriptor(eb_socket_t socketp, eb_user_data_t user, eb_descriptor_callback_t cb) {
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_link* link;
  eb_device_t devicep, next_devicep, first_devicep;
  eb_transport_t transportp, next_transportp, first_transportp;
  eb_link_t linkp;
  eb_descriptor_t fd;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  
  first_devicep = socket->first_device;
  first_transportp = aux->first_transport;
  
  /* Add all the transports */
  for (transportp = first_transportp; transportp != EB_NULL; transportp = next_transportp) {
    transport = EB_TRANSPORT(transportp);
    next_transportp = transport->next;
    
    fd = eb_transports[transport->link_type].fdes(transport, 0);
    (*cb)(user, fd); /* Invalidates: socket aux */
  }
  
  /* Add all the sockets to the listen set */
  for (devicep = first_devicep; devicep != EB_NULL; devicep = next_devicep) {
    device = EB_DEVICE(devicep);
    next_devicep = device->next;
    
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
  eb_device_t devicep, next_devicep;
  eb_transport_t transportp, next_transportp;
  eb_response_t responsep;
  eb_cycle_t cyclep;
  eb_socket_aux_t auxp;
  uint32_t time_cache;
  
  socket = EB_SOCKET(socketp);
  auxp = socket->aux;
  
  aux = EB_SOCKET_AUX(auxp);
  time_cache = aux->time_cache;
  
  /* Step 1. Kill any expired timeouts */
  while (eb_socket_timeout(socketp) <= time_cache) {
    /* Kill first */
    responsep = socket->first_response;
    response = EB_RESPONSE(responsep);
    
    cyclep = response->cycle;
    cycle = EB_CYCLE(cyclep);
    
    socket->first_response = response->next;
    
    if (cycle->callback)
      (*cycle->callback)(cycle->user_data, cycle->first, EB_TIMEOUT);
    socket = EB_SOCKET(socketp); /* Restore pointer */
    
    eb_cycle_destroy(cyclep);
    eb_free_cycle(cyclep);
    eb_free_response(responsep);
  }
  
  /* Step 2. Check all devices */
  
  /* Poll all the transports */
  aux = EB_SOCKET_AUX(auxp);
  for (transportp = aux->first_transport; transportp != EB_NULL; transportp = next_transportp) {
    transport = EB_TRANSPORT(transportp);
    next_transportp = transport->next;
    
    eb_device_slave(socketp, transportp, EB_NULL);
  }
  
  /* Add all the sockets to the listen set */
  socket = EB_SOCKET(socketp);
  for (devicep = socket->first_device; devicep != EB_NULL; devicep = next_devicep) {
    device = EB_DEVICE(devicep);
    next_devicep = device->next;
    
    eb_device_slave(socketp, device->transport, devicep);
  }
  
  return EB_OK;
}
