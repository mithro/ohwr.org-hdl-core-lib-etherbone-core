/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements UDP on posix sockets.
 */

#include "transport.h"
#include "posix-udp.h"

#include <stdlib.h>
#include <string.h>

eb_status_t eb_posix_udp_open(struct eb_transport* transportp, int port) {
  struct eb_posix_udp_transport* transport;
  eb_posix_sock_t sock;
  
  sock = eb_posix_ip_open(SOCK_DGRAM, port);
  if (sock == -1) return EB_BUSY;
  
  transport = (struct eb_posix_udp_transport*)transportp;
  transport->socket = sock;
  
  return EB_OK;
}

void eb_posix_udp_close(struct eb_transport* transportp) {
  struct eb_posix_udp_transport* transport;
  
  transport = (struct eb_posix_udp_transport*)transportp;
  eb_posix_ip_close(transport->socket);
}

eb_status_t eb_posix_udp_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address) {
  struct eb_posix_udp_link* link;
  struct sockaddr_storage sa;
  socklen_t len;
  
  len = eb_posix_ip_resolve("udp/", address, SOCK_DGRAM, &sa);
  if (len == -1) return EB_ADDRESS;
  
  link = (struct eb_posix_udp_link*)linkp;
  link->sa = (struct sockaddr_storage*)malloc(sizeof(struct sockaddr_storage));
  link->sa_len = len;
  
  memcpy(link->sa, &sa, len);
  
  return EB_OK;
}

void eb_posix_udp_disconnect(struct eb_transport* transport, struct eb_link* linkp) {
  struct eb_posix_udp_link* link;

  link = (struct eb_posix_udp_link*)linkp;
  free(link->sa);
}
