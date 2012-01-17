/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This provides common methods for UDP/TCP.
 */

#include "posix-ip.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

#define EB_DEFAULT_PORT 60368 /* 0xEBD0 */
#define EB_DEFAULT_PORT_STR "60368"

void eb_posix_ip_close(eb_posix_sock_t sock) {
  close(sock);
}

eb_posix_sock_t eb_posix_ip_open(int type, int port) {
  struct addrinfo hints, *match, *i;
  eb_posix_sock_t sock;
  int protocol;
  long val;
  char ports[30];
  
  switch (type) {
  case SOCK_DGRAM:  protocol = IPPROTO_UDP; break;
  case SOCK_STREAM: protocol = IPPROTO_TCP; break;
  default: return -1;
  }
  
  /* Find a matching address for this port */
  
  memset(&hints, 0, sizeof(struct addrinfo));
  hints.ai_family = PF_UNSPEC;  /* Not restricted to a given IP version */
  hints.ai_socktype = type;     /* STREAM/DGRAM as requested */
  hints.ai_protocol = protocol; /* TCP/UDP over IP to exclude non IPv* protocols */
  hints.ai_flags = AI_PASSIVE;  /* Suitable for binding a socket */
  
  if (port == 0) port = EB_DEFAULT_PORT;
  
  sprintf(ports, "%d", port);
  if (getaddrinfo(0, ports, &hints, &match) < 0)
    return -1;
  
  for (i = match; i; i = i->ai_next) {
    sock = socket(i->ai_family, i->ai_socktype, i->ai_protocol);
    if (sock == -1) continue;
    if (bind(sock, i->ai_addr, i->ai_addrlen) == 0) break;
    eb_posix_ip_close(sock);
  }
  
  freeaddrinfo(match);
  if (!i) return -1;
  
  /* Set it non-blocking */
  val = 1;
  ioctl(sock, FIONBIO, &val);
  
  return sock;
}

socklen_t eb_posix_ip_resolve(const char* prefix, const char* address, int type, struct sockaddr_storage* out) {
  struct addrinfo hints, *match;
  int len, protocol;
  char host[250];
  const char* port, *slash;
  
  len = strlen(prefix);
  if (strncmp(address, prefix, len))
    return -1;
  address += len;
  if (strlen(address) >= sizeof(host)-1) 
    return -1;
  
  slash = strchr(address, '/');
  if (slash == 0) {
    strcpy(host, address);
    port = EB_DEFAULT_PORT_STR;
  } else {
    len = slash - address;
    strncpy(host, address, len);
    host[len] = 0;
    port = slash+1;
  }
  
  switch (type) {
  case SOCK_DGRAM:  protocol = IPPROTO_UDP; break;
  case SOCK_STREAM: protocol = IPPROTO_TCP; break;
  default: return -1;
  }
  
  memset(&hints, 0, sizeof(struct addrinfo));
  hints.ai_family = PF_UNSPEC;  /* Not restricted to a given IP version */
  hints.ai_socktype = type;     /* STREAM/DGRAM as requested */
  hints.ai_protocol = protocol; /* TCP/UDP over IP to exclude non IPv* protocols */
  hints.ai_flags = 0;
  
  if (getaddrinfo(host, port, &hints, &match) < 0)
    return -1;
  
  memcpy(out, match->ai_addr, match->ai_addrlen);
  len = match->ai_addrlen;
  
  freeaddrinfo(match);
  return len;
}
