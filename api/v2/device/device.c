/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone device data structure.
 */

#include "device.h"
#include "../memory/memory.h"

eb_status_t eb_device_open(eb_socket_t socketp, const char* address, eb_width_t proposed_addr_widths, eb_width_t proposed_port_widths, int attempts, eb_device_t* result) {
  eb_device_t devicep;
  struct eb_device* device;
  struct eb_socket* socket;
  uint8_t link_type;
  
  devicep = eb_new_device();
  if (devicep == EB_NULL)
    return EB_OOM;
  
  device = EB_DEVICE(devicep);
  device->socket = socketp;
  device->ready = EB_NULL;
  device->unready = 0;
  device->widths = proposed_addr_widths << 4 | proposed_port_widths;
  
  /* Find an appropriate link !!! */
/*
  for (link_type = 0; link_type != eof; ++link_type) {
    link = link_plugin[link_type].process(address);
    if (link != EB_NULL) {
      device->link_type = link_type;
      device->link = link;
      break;
    }
  }
  
  if (link_type == eof) {
    eb_free_device(devicep);
    return EB_ADDRESS;
  }
*/
  
  socket = EB_SOCKET(socketp);
  device->next = socket->first_device;
  socket->first_device = devicep;
  return EB_OK;
}
