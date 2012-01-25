/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements blocking wait using select.
 */

#include "transport.h"
#include "../glue/socket.h"
#include "../glue/device.h"
#include "../memory/memory.h"

#include <sys/types.h>
#include <sys/time.h>
#include <sys/select.h>
#include <unistd.h>

int eb_socket_block(eb_socket_t socketp, int timeout_us) {
  struct eb_socket* socket;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_response* response;
  struct eb_link* link;
  struct timeval timeout, start, stop, *timeoutp;
  eb_device_t devicep;
  eb_transport_t transportp;
  eb_link_t linkp;
  fd_set rfds;
  int fd, nfd;
  uint16_t udelta;
  int16_t sdelta;
  
  socket = EB_SOCKET(socketp);
  
  gettimeofday(&start, 0);
  
  FD_ZERO(&rfds);
  nfd = 0;
  
  /* Add all the transports */
  for (transportp = socket->first_transport; transportp != EB_NULL; transportp = transport->next) {
    transport = EB_TRANSPORT(transportp);
    
    fd = eb_transports[transport->link_type].fdes(transport, 0);
    if (fd > nfd) nfd = fd;
    FD_SET(fd, &rfds);
  }
  
  /* Add all the sockets to the listen set */
  for (devicep = socket->first_device; devicep != EB_NULL; devicep = device->next) {
    device = EB_DEVICE(devicep);
    
    transportp = device->transport;
    linkp = device->link;
    transport = EB_TRANSPORT(transportp);
    link = EB_LINK(linkp);
    
    fd = eb_transports[transport->link_type].fdes(transport, link);
    if (fd > nfd) nfd = fd;
    FD_SET(fd, &rfds);
  }
  
  /* Find the first timeout */
  if (socket->first_response == EB_NULL)
    socket->first_response = eb_socket_flip_last(socketp);
  
  /* Determine how long until deadline expires */ 
  if (socket->first_response != EB_NULL) {
    response = EB_RESPONSE(socket->first_response);
    
    udelta = response->deadline - ((uint16_t)start.tv_sec);
    sdelta = udelta; /* Sign conversion */
    if (sdelta < 0) {
      timeout_us = 0;
    } else {
      if (timeout_us == -1 || sdelta*1000000 < timeout_us)
        timeout_us = sdelta*1000000;
    }
  }
  
  timeout.tv_sec  = timeout_us / 1000000;
  timeout.tv_usec = timeout_us % 1000000;
  
  if (timeout_us == -1)
    timeoutp = 0;
  else 
    timeoutp = &timeout;
  
  select(nfd+1, &rfds, 0, 0, timeoutp);
  gettimeofday(&stop, 0);
  
  return (stop.tv_sec - start.tv_sec)*1000000 + (stop.tv_usec - start.tv_usec);
}
