#include "udp.h"
#include "fec.h"

#include <stdlib.h>
#include <assert.h>

#ifdef USE_WINSOCK
#include <winsock2.h>
#include <windows.h>
#include <errno.h>
typedef int socklen_t;
#else
#include <net/if_arp.h>
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

#define ETHERTYPE	0xa0a0
#define EB_PORT		0xEBD0

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

  fec_open();

  if (flags == PROTO_ETHERNET) {
#ifndef USE_WINSOCK
    sock.fd = socket(PF_PACKET, SOCK_DGRAM, htons(ETHERTYPE));
#else
    /* !!! */
#endif
    sock.mode = PROTO_ETHERNET;
    /* Unneeded with UDP */
    sock.ip = 0;
    sock.port = -1;
  } else {
    assert (flags == PROTO_UDP);
    sock.fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    sock.mode = PROTO_UDP;
    sock.ip = 0x7F000001; /* find local address !!! */
    sock.port = port?port:EB_PORT;
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
  copy = (char*)malloc(strlen(address) + 1);
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
    port = EB_PORT;
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
  
  /* Find MAC from arp cache */
  if (sock.mode == PROTO_ETHERNET) {
#ifndef USE_WINSOCK
    struct arpreq areq;
    struct sockaddr_in sin;
    int attempts = 3;
    int udp;
    
    if ((udp = socket(PF_INET, SOCK_DGRAM, 0)) == -1) {
      free(copy);
      return -1;
    }
    
    memcpy(&sin, &result->sin, sizeof(sin));
    result->sin.sin_port = htons(7); /* echo service */
    
    memset(&areq, 0, sizeof(areq));
    memcpy(&areq.arp_pa, &result->sin, sizeof(result->sin));
    areq.arp_ha.sa_family = ARPHRD_ETHER;
    strncpy(areq.arp_dev, "eth0", 15);
    
    while (attempts-- > 0 && 
           !areq.arp_ha.sa_data[0] && 
           !areq.arp_ha.sa_data[1] && 
           !areq.arp_ha.sa_data[2] && 
           !areq.arp_ha.sa_data[3] && 
           !areq.arp_ha.sa_data[4] && 
           !areq.arp_ha.sa_data[5]) {
      /* Send a UDP message to trigger ARP lookup */
      sendto(udp, "echo", 4, 0, (struct sockaddr*)&sin, sizeof(sin));
      sleep(1);
      ioctl(udp, SIOCGARP, &areq);
    }
    close(udp);
    
    memset(&result->sll, 0, sizeof(result->sll));
    result->sll.sll_family = PF_PACKET;
    result->sll.sll_ifindex = 0;
    result->sll.sll_halen = 6;
    memcpy(&result->sll.sll_addr, &areq.arp_ha.sa_data, 6);
    
    if (!areq.arp_ha.sa_data[0] && 
        !areq.arp_ha.sa_data[1] && 
        !areq.arp_ha.sa_data[2] && 
        !areq.arp_ha.sa_data[3] && 
        !areq.arp_ha.sa_data[4] && 
        !areq.arp_ha.sa_data[5]) {
      free(copy);
      return -1;
    }
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

const unsigned char* udp_socket_recv_nb(udp_socket_t sock, udp_address_t* address, unsigned char* buf, unsigned int* len) {
  int result;
  
  if (sock.mode == PROTO_UDP) {
    socklen_t slen = sizeof(address->sin);
    result = recvfrom(sock.fd, (char*)buf, *len, 0, (struct sockaddr*)&address->sin, &slen);
    
    if (result < 0 || slen != sizeof(address->sin))
      return 0;
    
    *len = result;
    return buf;
  }  else {
    int port;
    const unsigned char* cbuf;
    unsigned int feclen;
    unsigned int ip;
    
#ifndef USE_WINSOCK
    socklen_t slen = sizeof(address->sll);
    result = recvfrom(sock.fd, buf, *len, 0, (struct sockaddr*)&address->sll, &slen);
#else
    result = -1;
    /* !!! */
#endif
    
    if (result <= 0)
      return 0;
    
    feclen = result;
    if ((cbuf = fec_decode(buf, &feclen)) == 0)
      return 0;
    
    if (feclen < 28)
      return 0;
      
    /* Confirm it's for us */
    if (cbuf[0] != 0x45) return 0; /* IPv4 with no options */
    if (cbuf[9] != 19) return 0; /* UDP? */
    
    ip = (unsigned int)cbuf[16] << 24 
       | (unsigned int)cbuf[17] << 16
       | (unsigned int)cbuf[18] <<  8
       | (unsigned int)cbuf[19] <<  0;
    
    port = (int)cbuf[22] << 8 | cbuf[23];
    
    if (port != sock.port) return 0;
    
    /* Rip out source IP+port for use in replies */
    memset(&address->sin, 0, sizeof(address->sin));
    address->sin.sin_family = PF_INET;
    memcpy(&address->sin.sin_addr, cbuf+12, 4);
    address->sin.sin_port = htons((int)cbuf[20] << 8 | cbuf[21]);
    
    /* Remove the IP+UDP header before handing off to etherbone */
    *len = feclen-28;
    return cbuf+28;
  }
}

void udp_socket_send(udp_socket_t sock, udp_address_t* address, unsigned char* buf, unsigned int len) {
  if (sock.mode == PROTO_UDP) {
    sendto(sock.fd, (char*)buf, len, 0, (struct sockaddr*)&address->sin, sizeof(address->sin));
  } else {
    unsigned char* ip = (unsigned char*)malloc(len+28);
    const unsigned char* coded;
    unsigned int coded_len;
    int i;

    /* Fill in IP and UDP headers */
    
    ip[0] = 0x45; /* IPv4 */
    ip[1] = 0;    /* TOS=0, ECN=no */
    /* length */
    ip[2] = (len+20) >> 8; 
    ip[3] = (len+20) & 0xFF;
    /* id=0 and not fragmented ip[4-7] */
    ip[8] = 63; /* TTL */
    ip[9] = 17; /* UDP */
    /* checksum */
    ip[10] = 0;
    ip[11] = 0;
    /* Source and dest IPs */
    /* memcpy(ip+12, ...., 4); */
    memcpy(ip+16, &address->sin.sin_addr, 4);
    
    /* UDP source and dest ports */
    ip[20] = sock.port >> 8;
    ip[21] = sock.port & 0xFF;
    ip[22] = ntohs(address->sin.sin_port) >> 8;
    ip[23] = ntohs(address->sin.sin_port) & 0xFF;
    /* UDP length and checksum */
    ip[24] = (len+8) >> 8;
    ip[25] = (len+8) & 0xFF;
    ip[26] = 0; /* checksum = 0 means not filled in */
    ip[27] = 0;
    
    /* Payload */
    memcpy(ip+28, buf, len);
    
    for (i = 0; coded_len = len, (coded = fec_encode(ip, &coded_len, i)) != 0; ++i) {
#ifndef USE_WINSOCK
      sendto(sock.fd, coded, coded_len, 0, (struct sockaddr*)&address->sll, sizeof(address->sll));
#else
      /* !!! */
#endif
    }
    
    assert (sock.mode == PROTO_ETHERNET);
  }
}
