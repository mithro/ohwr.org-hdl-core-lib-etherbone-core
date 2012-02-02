/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements SSH tunnelling.
 */

#ifndef EB_SSH_H
#define EB_SSH_H

#define EB_SSH_MTU 0

EB_PRIVATE eb_status_t eb_ssh_open(struct eb_transport* transport, int port);
EB_PRIVATE void eb_ssh_close(struct eb_transport* transport);
EB_PRIVATE eb_status_t eb_ssh_connect(struct eb_transport* transport, struct eb_link* link, const char* address);
EB_PRIVATE void eb_ssh_disconnect(struct eb_transport* transport, struct eb_link* link);
EB_PRIVATE eb_descriptor_t eb_ssh_fdes(struct eb_transport* transportp, struct eb_link* linkp);
EB_PRIVATE int eb_ssh_poll(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len);
EB_PRIVATE int eb_ssh_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len);
EB_PRIVATE void eb_ssh_send(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len);

struct eb_ssh_transport {
};

struct eb_ssh_link {
  eb_descriptor_t socket;
};

#endif
