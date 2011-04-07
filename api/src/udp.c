#include "udp.h"

#include <stdlib.h>
#include <assert.h>

#ifdef USE_WINSOCK
#include <winsock2.h>
#include <windows.h>
#include <errno.h>
typedef int socklen_t;
#else
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <arpa/inet.h>
#include <string.h>
#include <netdb.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>
#endif

void udp_socket_close(udp_socket_t sock) {
#ifdef USE_WINSOCK
  closesocket(sock.fd);
#else
  close(sock.fd);
#endif
}

int udp_socket_open(int port, int flags, udp_socket_t* result) {
  unsigned long val;
  udp_socket_t sock;

#ifdef USE_WINSOCK
  static int init = 0;
  WORD version;
  WSADATA wsaData;
  
  if (!init) {
    init = 1;
    version = MAKEWORD (2,2);
    WSAStartup (version, &wsaData);
  }
#endif

  if (flags == PROTO_ETHERNET) {
#ifndef USE_WINSOCK
    sock.fd = socket(PF_PACKET, SOCK_DGRAM, htons(0xa0a0));
#else
    /* !!! */
#endif
    sock.mode = PROTO_ETHERNET;
  } else {
    assert (flags == PROTO_UDP);
    sock.fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sock.mode = PROTO_UDP;
  }
  
  if (sock.fd < 0) return -1;
  
  /* Set it non-blocking */
  val = 1;
#ifdef USE_WINSOCK
  ioctlsocket(sock.fd, FIONBIO, &val);
#else
  ioctl(sock.fd, FIONBIO, &val);
#endif
  
  if (sock.mode == PROTO_UDP) {
    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));
    sin.sin_family = PF_INET;
    sin.sin_port = htons(port);
    /* Leave sin.sin_addr unset -> bind to all */
    
    if (bind(sock.fd, (struct sockaddr*)&sin, sizeof(sin)) < 0) {
      udp_socket_close(sock);
      return -1;
    }
  }
  
  *result = sock;
  return 0;
}

int udp_socket_descriptor(udp_socket_t sock) {
  return sock.fd;
}

int udp_socket_resolve(udp_socket_t sock, const char* address, udp_address_t* result) {
  char* copy;
  char* colon;
  int port;
  struct hostent* hent;
  
  /* Clone the string so we can parse the colon */
  copy = malloc(strlen(address) + 1);
  if (copy == 0) return -1;
  strcpy(copy, address);
  
  colon = strchr(copy, ':');
  if (colon) {
    *colon++ = 0;
    if (!*colon) {
      free(copy);
      return -1;
    }
    
    port = strtol(colon, &colon, 10);
    if (*colon) {
      free(copy);
      return -1;
    }
    
    /* Check for under/overflow */
    if (port <= 0 || port > 65535) {
      free(copy);
      return -1;
    }
  } else {
    port = 0xEBD0;
  }
  
  hent = gethostbyname(copy);
  if (!hent) {
    free(copy);
    return -1;
  }
  
  if (hent->h_addrtype != PF_INET) {
    free(copy);
    return -1;
  }
  
  memset(&result->sin, 0, sizeof(result->sin));
  result->sin.sin_family = PF_INET;
  result->sin.sin_port = htons(port);
  memcpy(&result->sin.sin_addr, hent->h_addr_list[0], sizeof(result->sin.sin_addr));
  
  if (sock.mode == PROTO_ETHERNET) {
#ifndef USE_WINSOCK
    memset(&result->sll, 0, sizeof(result->sll));
    /* !!! ARP */
#else
    /* !!! */
#endif
  }
  
  free(copy);
  return 0;
}

int udp_socket_compare(udp_address_t* a, udp_address_t* b) {
  return memcmp(&a->sin, &b->sin, sizeof(a->sin));
}

int udp_socket_block(udp_socket_t sock, int timeout_us) {
#ifdef USE_WINSOCK
  struct timeval wait;
  LARGE_INTEGER before, after;
  FILETIME ft;
#else
  struct timeval wait, before, after;
#endif
  fd_set rfds;
  int used;
  
  wait.tv_sec  = timeout_us / 1000000;
  wait.tv_usec = timeout_us % 1000000;
  
  FD_ZERO(&rfds);
  FD_SET(sock.fd, &rfds);
  
#ifdef USE_WINSOCK
  GetSystemTimeAsFileTime(&ft);
  before.LowPart = ft.dwLowDateTime;
  before.HighPart = ft.dwHighDateTime;
  select(sock.fd+1, &rfds, 0, 0, &wait);
  GetSystemTimeAsFileTime(&ft);
  after.LowPart = ft.dwLowDateTime;
  after.HighPart = ft.dwHighDateTime;
  
  return (after.QuadPart - before.QuadPart) / 10;
#else
  gettimeofday(&before, 0);
  select(sock.fd+1, &rfds, 0, 0, &wait);
  gettimeofday(&after, 0);
  
  used = (after.tv_sec - before.tv_sec);
  used *= 1000000;
  used += (after.tv_usec - before.tv_usec);
#endif
  return used;
}

int udp_socket_recv_nb(udp_socket_t sock, udp_address_t* address, unsigned char* buf, unsigned int len) {
  int result;
  
  if (sock.mode == PROTO_UDP) {
    socklen_t slen = sizeof(address->sin);
    result = recvfrom(sock.fd, (char*)buf, len, 0, (struct sockaddr*)&address->sin, &slen);
    if (slen != sizeof(address->sin)) result = -1;
  }  else {
    assert (sock.mode == PROTO_ETHERNET);
#ifndef USE_WINSOCK
    /* !!! */
#else
    result = -1;  /* !!! */
#endif
  }
  
  if (result == -1 && errno == EAGAIN)
    return 0;
  if (result < 0)
    return -1;
  
  return result;
}

void udp_socket_send(udp_socket_t sock, udp_address_t* address, unsigned char* buf, unsigned int len) {
  if (sock.mode == PROTO_UDP) {
    sendto(sock.fd, (char*)buf, len, 0, (struct sockaddr*)&address->sin, sizeof(address->sin));
  } else {
    assert (sock.mode == PROTO_ETHERNET);
#ifndef USE_WINSOCK
    /* !!! */
#else
    /* !!! */
#endif
  }
}
