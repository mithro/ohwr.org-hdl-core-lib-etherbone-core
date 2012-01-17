/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements UDP on posix sockets.
 */

#include "transport.h"
#include "posix-udp.h"

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
  socklen_t len;
  
  len = eb_posix_ip_resolve("udp/", address, SOCK_DGRAM, &link->sa);
  if (len == -1) return EB_ADDRESS;
  
  link = (struct eb_posix_udp_link*)linkp;
  link->sa_len = len;
  return EB_OK;
}

void eb_posix_udp_disconnect(struct eb_transport* transport, struct eb_link* link) {
  /* noop */
}
