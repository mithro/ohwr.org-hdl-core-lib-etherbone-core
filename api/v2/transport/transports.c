/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This combines all the supported transport modules.
 */

#include "transport.h"
#include "posix-udp.h"
#include "posix-tcp.h"
#include "ssh.h"

struct eb_transport_ops eb_transports[] = {
  {
    EB_POSIX_UDP_MTU,
    eb_posix_udp_open,
    eb_posix_udp_close,
    eb_posix_udp_connect,
    eb_posix_udp_disconnect
  },
  {
    EB_POSIX_TCP_MTU,
    eb_posix_tcp_open,
    eb_posix_tcp_close,
    eb_posix_tcp_connect,
    eb_posix_tcp_disconnect
  },
  {
    EB_SSH_MTU,
    eb_ssh_open,
    eb_ssh_close,
    eb_ssh_connect,
    eb_ssh_disconnect
  }
};

const unsigned int eb_transport_size = sizeof(eb_transports) / sizeof(struct eb_transport_ops);
