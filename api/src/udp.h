/* Copyright (C) 2011 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 */
#ifndef UDP_BSD_H
#define UDP_BSD_H

#ifdef __WIN32
#define USE_WINSOCK
#endif

#ifdef USE_WINSOCK
#include <winsock2.h>
#else
#include <netinet/in.h>
#endif

#define UDP_SEGMENT_SIZE 1472

typedef struct sockaddr_in udp_address_t;
typedef int udp_socket_t;

#ifdef __cplusplus
extern "C" {
#endif

int udp_socket_open(int port, udp_socket_t* result);
void udp_socket_close(udp_socket_t sock);
int udp_socket_resolve(udp_socket_t sock, const char* address, udp_address_t* result);
int udp_socket_compare(udp_address_t* a, udp_address_t* b);

int udp_socket_descriptor(udp_socket_t sock);
int udp_socket_block(udp_socket_t sock, int timeout_us); // Block until a read is ready

int udp_socket_recv_nb(udp_socket_t sock, udp_address_t* address, unsigned char* buf, unsigned int len);
void udp_socket_send(udp_socket_t sock, udp_address_t* address, unsigned char* buf, unsigned int len);

#ifdef __cplusplus
}
#endif

#endif
