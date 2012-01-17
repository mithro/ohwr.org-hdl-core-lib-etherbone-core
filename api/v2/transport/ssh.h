/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements SSH tunnelling.
 */

#ifndef EB_SSH_H
#define EB_SSH_H

#define EB_SSH_MTU 4000

eb_status_t eb_ssh_open(struct eb_transport* transport, int port);
void eb_ssh_close(struct eb_transport* transport);
eb_status_t eb_ssh_connect(struct eb_transport* transport, struct eb_link* link, const char* address);
void eb_ssh_disconnect(struct eb_transport* transport, struct eb_link* link);

struct eb_ssh_transport {
};

struct eb_ssh_link {
  int socket;
};

#endif
