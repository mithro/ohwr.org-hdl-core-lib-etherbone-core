/** @file posix-tcp.c
 *  @brief This implements a TCP binding using posix sockets.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  The transport carries a port for accepting inbound connections.
 *  Passive devices are created for inbound connections.
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

#include "posix-ip.h"
#include "posix-tcp.h"
#include "transport.h"

#include <errno.h>

eb_status_t eb_posix_tcp_open(struct eb_transport* transportp, const char* port) {
  struct eb_posix_tcp_transport* transport;
  eb_posix_sock_t sock;
  
  sock = eb_posix_ip_open(SOCK_STREAM, port);
  if (sock == -1) return EB_BUSY;
  
  if (listen(sock, 5) < 0) {
    eb_posix_ip_close(sock);
    return EB_ADDRESS; 
  }

  eb_posix_ip_force_non_blocking(sock, 1);
  
  transport = (struct eb_posix_tcp_transport*)transportp;
  transport->port = sock;

  return EB_OK;
}

void eb_posix_tcp_close(struct eb_transport* transportp) {
  struct eb_posix_tcp_transport* transport;
  
  transport = (struct eb_posix_tcp_transport*)transportp;
  eb_posix_ip_close(transport->port);
}

eb_status_t eb_posix_tcp_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address) {
  struct eb_posix_tcp_link* link;
  struct sockaddr_storage sa;
  eb_posix_sock_t sock;
  socklen_t len;
  
  link = (struct eb_posix_tcp_link*)linkp;
  
  len = eb_posix_ip_resolve("tcp/", address, SOCK_STREAM, &sa);
  if (len == -1) return EB_ADDRESS;
  
  sock = socket(sa.ss_family, SOCK_STREAM, IPPROTO_TCP);
  if (sock == -1) return EB_FAIL;
  
  if (connect(sock, (struct sockaddr*)&sa, len) < 0) {
    eb_posix_ip_close(sock);
    return EB_FAIL;
  }
  
  link->socket = sock;
  return EB_OK;
}

void eb_posix_tcp_disconnect(struct eb_transport* transport, struct eb_link* linkp) {
  struct eb_posix_tcp_link* link;
  
  link = (struct eb_posix_tcp_link*)linkp;
  eb_posix_ip_close(link->socket);
}

eb_descriptor_t eb_posix_tcp_fdes(struct eb_transport* transportp, struct eb_link* linkp) {
  struct eb_posix_tcp_transport* transport;
  struct eb_posix_tcp_link* link;
  
  if (linkp) {
    link = (struct eb_posix_tcp_link*)linkp;
    return link->socket;
  } else {
    transport = (struct eb_posix_tcp_transport*)transportp;
    return transport->port;
  }
}

int eb_posix_tcp_poll(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_posix_tcp_link* link;
  int result;
  
  if (linkp == 0) return 0;  /* !!! accept. note: initial device widths must be 0 */
  
  link = (struct eb_posix_tcp_link*)linkp;
  
  /* Set non-blocking */
  eb_posix_ip_non_blocking(link->socket, 1);
  
  result = recv(link->socket, (char*)buf, len, MSG_DONTWAIT);
  
  if (result == -1 && errno == EAGAIN) return 0;
  if (result == 0) return -1;
  return result;
}

int eb_posix_tcp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_posix_tcp_link* link;
  int result;
  
  if (linkp == 0) return 0;
  
  link = (struct eb_posix_tcp_link*)linkp;

  /* Set blocking */
  eb_posix_ip_non_blocking(link->socket, 0);

  result = recv(link->socket, (char*)buf, len, 0);
  
  /* EAGAIN impossible on blocking read */
  if (result == 0) return -1;
  return result;
}

void eb_posix_tcp_send(struct eb_transport* transportp, struct eb_link* linkp, const uint8_t* buf, int len) {
  struct eb_posix_tcp_link* link;
  
  /* linkp == 0 impossible if poll == 0 returns 0 */
  
  link = (struct eb_posix_tcp_link*)linkp;
  
  /* Set blocking */
  eb_posix_ip_non_blocking(link->socket, 0);

  send(link->socket, (const char*)buf, len, 0);
}

int eb_posix_tcp_accept(struct eb_transport* transportp, struct eb_link* result_linkp) {
  struct eb_posix_tcp_transport* transport;
  struct eb_posix_tcp_link* result_link;
  eb_posix_sock_t sock;
  
  transport = (struct eb_posix_tcp_transport*)transportp;
  
  sock = accept(transport->port, 0, 0);
  if (sock == -1) {
    if (errno != EAGAIN) return -1;
    return 0;
  }
  
  if (result_linkp != 0) {
    result_link = (struct eb_posix_tcp_link*)result_linkp;
    result_link->socket = sock;
    return 1;
  } else {
    eb_posix_ip_close(sock);
    return 0;
  }
}
