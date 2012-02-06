/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements UDP on posix sockets.
 */

#define ETHERBONE_IMPL

#include "transport.h"
#include "posix-udp.h"
#include "../glue/socket.h"
#include "../glue/device.h"

#include <stdlib.h>
#include <string.h>
#include <errno.h>

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

eb_descriptor_t eb_posix_udp_fdes(struct eb_transport* transportp, struct eb_link* linkp) {
  struct eb_posix_udp_transport* transport;
  
  transport = (struct eb_posix_udp_transport*)transportp;
  if (linkp == 0) {
    return transport->socket;
  } else {
    return -1; /* no per-link socket */
  }
}

/* !!! global is not the best approach. break multi-threading. */
static struct sockaddr_storage eb_posix_udp_sa;
static socklen_t eb_posix_udp_sa_len;

int eb_posix_udp_poll(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_posix_udp_transport* transport;
  int result;
  
  if (linkp != 0) return 0; /* Only recv top-level */
  
  transport = (struct eb_posix_udp_transport*)transportp;
  
  eb_posix_udp_sa_len = sizeof(eb_posix_udp_sa);
  result = recvfrom(transport->socket, buf, len, MSG_DONTWAIT, (struct sockaddr*)&eb_posix_udp_sa, &eb_posix_udp_sa_len);
  
  if (result == -1 && errno == EAGAIN) return 0;
  if (result == 0) return -1;
  return result;
}

int eb_posix_udp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  /* Should never happen on a non-stream socket */
  return -1;
}

void eb_posix_udp_send(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_posix_udp_transport* transport;
  struct eb_posix_udp_link* link;
  
  transport = (struct eb_posix_udp_transport*)transportp;
  link = (struct eb_posix_udp_link*)linkp;
  
  if (link == 0)
    sendto(transport->socket, buf, len, 0, (struct sockaddr*)&eb_posix_udp_sa, eb_posix_udp_sa_len);
  else
    sendto(transport->socket, buf, len, 0, (struct sockaddr*)link->sa, link->sa_len);
}
