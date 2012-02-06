/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone format functions.
 */

#ifndef EB_FORMAT_H
#define EB_FORMAT_H

#include "../glue/socket.h"
#include "../glue/device.h"
#include "../transport/transport.h"

typedef union {
  eb_data_t data;
  eb_address_t address;
} eb_max_align_t;

EB_PRIVATE void eb_device_slave(struct eb_socket* socket, struct eb_transport* transport, eb_device_t devicep, struct eb_device* device);

#endif
