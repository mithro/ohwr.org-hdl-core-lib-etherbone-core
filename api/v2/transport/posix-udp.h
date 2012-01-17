/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements UDP on posix sockets.
 */

#ifndef EB_POSIX_UDP_H
#define EB_POSIX_UDP_H

#include "posix-ip.h"

#define EB_POSIX_UDP_MTU 1472

eb_status_t eb_posix_udp_open(struct eb_transport* transport, int port);
void eb_posix_udp_close(struct eb_transport* transport);
eb_status_t eb_posix_udp_connect(struct eb_transport* transport, struct eb_link* link, const char* address);
void eb_posix_udp_disconnect(struct eb_transport* transport, struct eb_link* link);

struct eb_posix_udp_transport {
  eb_posix_sock_t socket;
};

struct eb_posix_udp_link {
  socklen_t sa_len;
  struct sockaddr_storage sa;
};

#endif
