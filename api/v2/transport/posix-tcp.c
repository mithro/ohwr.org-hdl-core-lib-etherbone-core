/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements UDP on posix sockets.
 */

#include "transport.h"
#include "posix-tcp.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>

eb_status_t eb_posix_tcp_open(struct eb_transport* transportp, int port) {
  struct eb_posix_tcp_transport* transport;
  eb_posix_sock_t sock;
  
  sock = eb_posix_ip_open(SOCK_STREAM, port);
  if (sock == -1) return EB_BUSY;
  
  if (listen(sock, 5) < 0) {
    eb_posix_ip_close(sock);
    return EB_ADDRESS; 
  }
  
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
  long val;
  
  link = (struct eb_posix_tcp_link*)linkp;
  
  len = eb_posix_ip_resolve("tcp/", address, SOCK_STREAM, &sa);
  if (len == -1) return EB_ADDRESS;
  
  sock = socket(sa.ss_family, SOCK_STREAM, IPPROTO_TCP);
  if (sock == -1) return EB_FAIL;
  
  if (connect(sock, (struct sockaddr*)&sa, len) < 0) {
    eb_posix_ip_close(sock);
    return EB_FAIL;
  }
  
  /* Set it non-blocking */
  val = 1;
  ioctl(sock, FIONBIO, &val);
  
  link->socket = sock;
  return EB_OK;
}

void eb_posix_tcp_disconnect(struct eb_transport* transport, struct eb_link* linkp) {
  struct eb_posix_tcp_link* link;
  
  link = (struct eb_posix_tcp_link*)linkp;
  eb_posix_ip_close(link->socket);
}

int eb_posix_tcp_fdes(struct eb_transport* transportp, struct eb_link* linkp) {
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
  struct eb_posix_tcp_transport* transport;
  struct eb_posix_tcp_link* link;
  
  if (linkp == 0) return -1; /* !!! accept */
  
  transport = (struct eb_posix_tcp_transport*)transportp;
  link = (struct eb_posix_tcp_link*)linkp;
  
  return recv(link->socket, buf, len, MSG_DONTWAIT);
}

int eb_posix_tcp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_posix_tcp_link* link;
  
  if (linkp == 0) return -1;
  
  link = (struct eb_posix_tcp_link*)linkp;
  return recv(link->socket, buf, len, 0);
}

void eb_posix_tcp_send(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_posix_tcp_link* link;
  
  link = (struct eb_posix_tcp_link*)linkp;
  send(link->socket, buf, len, 0);
}
