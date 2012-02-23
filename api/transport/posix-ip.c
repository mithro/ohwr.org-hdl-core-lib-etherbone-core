/** @file posix-ip.c
 *  @brief Common methods for UDP/TCP.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Implements common IPv4/6 agnostic socket handling.
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

#include <stdio.h>
#include <string.h>

#define EB_DEFAULT_PORT_STR "60368" /* 0xEBD0 */

void eb_posix_ip_close(eb_posix_sock_t sock) {
#ifdef __WIN32
  closesocket(sock);
#else
  close(sock);
#endif
}

eb_posix_sock_t eb_posix_ip_open(int type, const char* port) {
  struct addrinfo hints, *match, *i;
  eb_posix_sock_t sock;
  int protocol;
  
  switch (type) {
  case SOCK_DGRAM:  protocol = IPPROTO_UDP; break;
  case SOCK_STREAM: protocol = IPPROTO_TCP; break;
  default: return -1;
  }
  
  /* Find a matching address for this port */
  
  memset(&hints, 0, sizeof(struct addrinfo));
  hints.ai_family = PF_INET6;   /* Not restricted to a given IP version */
  hints.ai_socktype = type;     /* STREAM/DGRAM as requested */
  hints.ai_protocol = protocol; /* TCP/UDP over IP to exclude non IPv* protocols */
  hints.ai_flags = AI_PASSIVE;  /* Suitable for binding a socket */
  
  if (getaddrinfo(0, port?port:"0", &hints, &match) < 0)
    return -1;
  
  for (i = match; i; i = i->ai_next) {
    sock = socket(i->ai_family, i->ai_socktype, i->ai_protocol);
    if (sock == -1) continue;
    if (bind(sock, i->ai_addr, i->ai_addrlen) == 0) break;
    eb_posix_ip_close(sock);
  }
  
  freeaddrinfo(match);
  if (!i) return -1;
  
  return sock;
}

socklen_t eb_posix_ip_resolve(const char* prefix, const char* address, int type, struct sockaddr_storage* out) {
  struct addrinfo hints, *match;
  int len, protocol;
  char host[250];
  const char* port, *slash;
  
  len = strlen(prefix);
  if (strncasecmp(address, prefix, len))
    return -1;
  address += len;
  if (strlen(address) >= sizeof(host)-1) 
    return -1;
  
  slash = strchr(address, '/');
  if (slash == 0 || *(slash+1) == 0) {
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

void eb_posix_ip_force_non_blocking(eb_posix_sock_t sock, unsigned long on) {
#if defined(__WIN32)
  ioctlsocket(sock, FIONBIO, &on);
#else
  ioctl(sock, FIONBIO, &on);
#endif
}

void eb_posix_ip_non_blocking(eb_posix_sock_t sock, unsigned long on) {
#if defined(EB_POSIX_IP_NON_BLOCKING_NOOP)
  /* no-op. DONTWAIT is faster */
#else
  eb_posix_ip_force_non_blocking(sock, on);
#endif
}
