/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements UDP on posix sockets.
 */

#include "transport.h"
#include "ssh.h"

eb_status_t eb_ssh_open(struct eb_transport* transport, int port) {
  
  return EB_OK;
}

void eb_ssh_close(struct eb_transport* transport) {
}

eb_status_t eb_ssh_connect(struct eb_transport* transport, struct eb_link* link, const char* address) {
  return EB_OK;
}

void eb_ssh_disconnect(struct eb_transport* transport, struct eb_link* link) {
}
