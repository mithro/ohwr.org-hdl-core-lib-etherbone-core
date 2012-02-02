/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements polling all sockets for readiness.
 */

#define ETHERBONE_IMPL

#include <sys/time.h>

#include "../glue/socket.h"
#include "../glue/cycle.h"
#include "../memory/memory.h"
#include "../format/format.h"

eb_status_t eb_socket_poll(eb_socket_t socketp) {
  struct timeval tv;
  struct eb_socket* socket;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_response* response;
  struct eb_cycle* cycle;
  eb_device_t devicep;
  eb_transport_t transportp;
  eb_response_t responsep;
  eb_cycle_t cyclep;
  
  socket = EB_SOCKET(socketp);
  
  /* Step 1. Kill any expired timeouts */
  gettimeofday(&tv, 0);
  while (eb_socket_timeout(socketp, tv.tv_sec) <= tv.tv_sec) {
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
  for (transportp = socket->first_transport; transportp != EB_NULL; transportp = transport->next) {
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
