/** @file posix-udp.c
 *  @brief This implements a UDP binding using posix sockets.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  UDP links all share the same socket, only recording the target address.
 *  At the moment the target address is dynamically allocated. (!!! fixme)
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

// #define PACKET_DEBUG 1

#include "posix-ip.h"
#include "posix-udp.h"
#include "transport.h"
#include "../glue/socket.h"
#include "../glue/device.h"

#include <stdlib.h>
#include <string.h>
#include <errno.h>
#ifdef PACKET_DEBUG
#include <stdio.h>
#endif

eb_status_t eb_posix_udp_open(struct eb_transport* transportp, const char* port) {
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
  
  /* Set non-blocking */
  eb_posix_ip_non_blocking(transport->socket, 1);
  
  eb_posix_udp_sa_len = sizeof(eb_posix_udp_sa);
  result = recvfrom(transport->socket, (char*)buf, len, MSG_DONTWAIT, (struct sockaddr*)&eb_posix_udp_sa, &eb_posix_udp_sa_len);
  
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
  
#ifdef PACKET_DEBUG
  int i;
  fprintf(stderr, "<---- ");
  for (i = 0; i < len; ++i) fprintf(stderr, "%02x", buf[i]);
  fprintf(stderr, "\n");
#endif

  transport = (struct eb_posix_udp_transport*)transportp;
  link = (struct eb_posix_udp_link*)linkp;
  
  /* Set blocking */
  eb_posix_ip_non_blocking(transport->socket, 0);
  
  if (link == 0)
    sendto(transport->socket, (const char*)buf, len, 0, (struct sockaddr*)&eb_posix_udp_sa, eb_posix_udp_sa_len);
  else
    sendto(transport->socket, (const char*)buf, len, 0, (struct sockaddr*)link->sa, link->sa_len);
}
