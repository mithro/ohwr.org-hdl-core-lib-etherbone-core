/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone device data structure.
 */

#include "device.h"
#include "socket.h"
#include "../transport/transport.h"
#include "../memory/memory.h"

eb_status_t eb_device_open(eb_socket_t socketp, const char* address, eb_width_t proposed_widths, int attempts, eb_device_t* result) {
  eb_device_t devicep;
  eb_transport_t transportp;
  eb_link_t linkp;
  struct eb_transport* transport;
  struct eb_link* link;
  struct eb_device* device;
  struct eb_socket* socket;
  eb_status_t status;
  
  devicep = eb_new_device();
  if (devicep == EB_NULL)
    return EB_OOM;
  
  linkp = eb_new_link();
  if (linkp == EB_NULL) {
    eb_free_device(devicep);
    return EB_OOM;
  }
  
  device = EB_DEVICE(devicep);
  device->socket = socketp;
  device->ready = EB_NULL;
  device->unready = 0;
  device->widths = proposed_widths;
  
  socket = EB_SOCKET(socketp);
  link = EB_LINK(linkp);
  
  /* Find an appropriate link */
  for (transportp = socket->first_transport; transportp != EB_NULL; transportp = transport->next) {
    transport = EB_TRANSPORT(transportp);
    
    status = eb_transports[transport->link_type].connect(transport, link, address);
    if (status != EB_ADDRESS) break;
  }
  
  if (transportp == EB_NULL) {
    eb_free_link(linkp);
    eb_free_device(devicep);
    return EB_ADDRESS;
  }
  
  if (status == EB_OK) {
    device->next = socket->first_device;
    socket->first_device = devicep;
    return EB_OK;
  } else {
    eb_free_link(linkp);
    eb_free_device(devicep);
    return status;
  }
}

eb_status_t eb_device_close(eb_device_t devicep) {
  struct eb_socket* socket;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_link* link;
  struct eb_device* idev;
  eb_device_t* ptr, i;
  
  device = EB_DEVICE(devicep);
  
  if (device->ready != EB_NULL || device->unready != 0)
    return EB_BUSY;
  
  transport = EB_TRANSPORT(device->transport);
  link = EB_LINK(device->link);
  socket = EB_SOCKET(device->socket);
  
  /* Find it in the socket's list */
  for (ptr = &socket->first_device; (i = *ptr) != EB_NULL; ptr = &idev->next) {
    if (i == devicep) break;
    idev = EB_DEVICE(i);
  }
  
  /* Couldn't find the device?! */
  if (i == EB_NULL)
    return EB_FAIL;
  
  /* Remove it and close the link */
  *ptr = device->next;
  eb_transports[transport->link_type].disconnect(transport, link);
  
  eb_free_link(device->link);
  eb_free_device(devicep);
  
  return EB_OK;
}

eb_width_t eb_device_widths(eb_device_t devicep) {
  struct eb_device* device;
  
  device = EB_DEVICE(devicep);
  return device->widths;
}

eb_socket_t eb_device_socket(eb_device_t devicep) {
  struct eb_device* device;
  
  device = EB_DEVICE(devicep);
  return device->socket;
}

eb_status_t eb_device_read(eb_device_t device, eb_address_t address, eb_data_t* data, eb_user_data_t user, eb_callback_t cb) {
  eb_cycle_t cycle;
  
  cycle = eb_cycle_open(device, user, cb);
  if (cycle == EB_NULL) return EB_OOM;
  
  eb_cycle_read(cycle, address, data);
  eb_cycle_close(cycle);
  
  return EB_OK;
}

eb_status_t eb_device_write(eb_device_t device, eb_address_t address, eb_data_t data, eb_user_data_t user, eb_callback_t cb) {
  eb_cycle_t cycle;
  
  cycle = eb_cycle_open(device, user, cb);
  if (cycle == EB_NULL) return EB_OOM;
  
  eb_cycle_write(cycle, address, data);
  eb_cycle_close(cycle);
  
  return EB_OK;
}
