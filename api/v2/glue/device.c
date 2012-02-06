/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone device data structure.
 */

#define ETHERBONE_IMPL

#include "device.h"
#include "socket.h"
#include "widths.h"
#include "../transport/transport.h"
#include "../memory/memory.h"
#include "endian.h"

eb_status_t eb_device_open(eb_socket_t socketp, const char* address, eb_width_t proposed_widths, int attempts, eb_device_t* result) {
  eb_device_t devicep;
  eb_transport_t transportp;
  eb_link_t linkp;
  struct eb_transport* transport;
  struct eb_link* link;
  struct eb_device* device;
  struct eb_socket* socket;
  struct eb_socket_aux* aux;
  eb_status_t status;
  
  socket = EB_SOCKET(socketp);
  aux = EB_SOCKET_AUX(socket->aux);
  
  proposed_widths &= socket->widths;
  if (eb_width_possible(proposed_widths) == 0) {
    *result = EB_NULL;
    return EB_WIDTH;
  }
  
  devicep = eb_new_device();
  if (devicep == EB_NULL) {
    *result = EB_NULL;
    return EB_OOM;
  }
  
  linkp = eb_new_link();
  if (linkp == EB_NULL) {
    eb_free_device(devicep);
    *result = EB_NULL;
    return EB_OOM;
  }
  
  device = EB_DEVICE(devicep);
  device->socket = socketp;
  device->ready = EB_NULL;
  device->unready = 0;
  device->link = linkp;
  
  link = EB_LINK(linkp);
  
  /* Find an appropriate link */
  for (transportp = aux->first_transport; transportp != EB_NULL; transportp = transport->next) {
    transport = EB_TRANSPORT(transportp);
    
    status = eb_transports[transport->link_type].connect(transport, link, address);
    if (status != EB_ADDRESS) break;
  }
  
  if (transportp == EB_NULL) {
    eb_free_link(linkp);
    eb_free_device(devicep);
    *result = EB_NULL;
    return EB_ADDRESS;
  }
  
  if (status != EB_OK) {
    eb_free_link(linkp);
    eb_free_device(devicep);
    *result = EB_NULL;
    return status;
  }
  
  device->transport = transportp;
  device->next = socket->first_device;
  socket->first_device = devicep;
  
  /* If the connection is streaming, we must do exactly one handshake */
  if (eb_transports[transport->link_type].mtu == 0)
    attempts = 1;
  
  /* Try to determine port width */
  if (attempts == 0) {
    device->widths = EB_DATAX|EB_ADDRX;
  } else {
    device->widths = 0;
    do {
      uint8_t buf[8] = { 0x4E, 0x6F, 0x11, proposed_widths, 0x0, 0x0, 0x0, 0x0 };
      int timeout, got;
      
      *(uint32_t*)(buf+4) = htobe32((uint32_t)devicep);
      eb_transports[transport->link_type].send(transport, link, buf, sizeof(buf));
      
      timeout = 3000000; /* 3 seconds */
      while (timeout > 0 && device->widths == 0) {
        got = eb_socket_block(socketp, timeout);
        timeout -= got;
        eb_socket_poll(socketp);
      }
    } while (device->widths == 0 && --attempts != 0);
  }
  
  if (device->widths == 0) {
    eb_device_close(devicep);
    *result = EB_NULL;
    return EB_FAIL;
  }
  
  device->widths &= proposed_widths;
  if (eb_width_possible(device->widths) == 0) {
    eb_device_close(devicep);
    *result = EB_NULL;
    return EB_WIDTH;
  }
  
  device->widths = eb_width_refine(device->widths);
  
  *result = devicep;
  return EB_OK;
}

eb_status_t eb_device_close(eb_device_t devicep) {
  struct eb_socket* socket;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_link* link;
  struct eb_device* idev;
  eb_device_t* ptr, i;
  eb_link_t linkp;
  
  device = EB_DEVICE(devicep);
  
  if ((device->ready != EB_NULL && device->passive != devicep) || device->unready != 0)
    return EB_BUSY;
  
  transport = EB_TRANSPORT(device->transport);
  socket = EB_SOCKET(device->socket);
  
  /* Find it in the socket's list */
  for (ptr = &socket->first_device; (i = *ptr) != EB_NULL; ptr = &idev->next) {
    if (i == devicep) break;
    idev = EB_DEVICE(i);
  }
  
  /* Couldn't find the device?! */
  if (i == EB_NULL)
    return EB_FAIL;
  
  /* Remove it */
  *ptr = device->next;
  
  /* Close the link */
  linkp = device->link;
  if (linkp != EB_NULL) {
    link = EB_LINK(linkp);
    eb_transports[transport->link_type].disconnect(transport, link);
    eb_free_link(linkp);
  }
  
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
  if (cb == 0)
    eb_cycle_close_silently(cycle);
  else
    eb_cycle_close(cycle);
  
  return EB_OK;
}
