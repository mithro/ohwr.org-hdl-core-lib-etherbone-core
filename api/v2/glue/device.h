/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone device data structure.
 */

#ifndef EB_DEVICE_H
#define EB_DEVICE_H

#include "../etherbone.h"
#include "../transport/transport.h"

struct eb_device {
  eb_socket_t socket;
  eb_device_t next;
  
  eb_cycle_t ready;
  uint8_t unready;
  uint8_t widths;
  
  eb_link_t link;
  eb_transport_t transport;
};

#endif
