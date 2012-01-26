/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements UDP on posix sockets.
 */

#ifndef EB_POSIX_TCP_H
#define EB_POSIX_TCP_H

#include "posix-ip.h"

#define EB_POSIX_TCP_MTU 0

eb_status_t eb_posix_tcp_open(struct eb_transport* transport, int port);
void eb_posix_tcp_close(struct eb_transport* transport);
eb_status_t eb_posix_tcp_connect(struct eb_transport* transport, struct eb_link* link, const char* address);
void eb_posix_tcp_disconnect(struct eb_transport* transport, struct eb_link* link);
eb_descriptor_t eb_posix_tcp_fdes(struct eb_transport*, struct eb_link*);
int eb_posix_tcp_poll(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len);
int eb_posix_tcp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len);
void eb_posix_tcp_send(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len);

struct eb_posix_tcp_transport {
  eb_posix_sock_t port;
};

struct eb_posix_tcp_link {
  eb_posix_sock_t socket;
};

#endif
