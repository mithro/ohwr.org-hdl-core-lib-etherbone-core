/** @file ssh.h
 *  @brief This implements an SSH binding using popen().
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Etherbone over ssh is implemented using a helper process.
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

#ifndef EB_SSH_H
#define EB_SSH_H

#include "../transport/transport.h"

#define EB_SSH_MTU 0

EB_PRIVATE eb_status_t eb_ssh_open(struct eb_transport* transport, const char* port);
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
