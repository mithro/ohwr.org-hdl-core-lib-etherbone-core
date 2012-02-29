/** @file sdwb.c
 *  @brief Implement the SDWB data structure on the local bus.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  We reserved the low 8K memory region for this device.
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

#define ETHERBONE_IMPL

#include "socket.h"
#include "../format/bigendian.h"
#include "../memory/memory.h"

#include <string.h>

static eb_data_t eb_sdwb_extract(void* data, eb_width_t width, eb_address_t addr) {
  eb_data_t out;
  uint8_t* bytes = (uint8_t*)data;
  eb_width_t i;
  
  width &= EB_DATAX;
  for (i = 0; i < width; ++i) {
    out <<= 8;
    out |= bytes[addr+i];
  }
  
  return out;
}

static eb_data_t eb_sdwb_header(eb_width_t width, eb_address_t addr, int devices) {
  struct sdwb_header header;
  uint8_t magic[8] = { 0x53, 0x44, 0x57, 0x42, 0x48, 0x45, 0x41, 0x44 };
  
  memcpy(&header.magic[0], &magic[0], 8);
  header.wbidb_addr = htobe64(0x20);
  header.wbddb_addr = htobe64(0x40);
  header.wbddb_size = htobe64(devices * 0x50);
  
  return eb_sdwb_extract(&header, width, addr);
}

static eb_data_t eb_sdwb_id_block(eb_width_t width, eb_address_t addr) {
  struct sdwb_id_block id_block;
  
  id_block.bitstream_devtype = htobe64(0x0);
  id_block.bitstream_version = htobe32(1);
  id_block.bitstream_date    = htobe32(0x20121228); /* FIXME */
  memset(&id_block.bitstream_source, 0, 16);
  
  return eb_sdwb_extract(&id_block, width, addr);
}

static eb_data_t eb_sdwb_device(sdwb_device_descriptor_t device, eb_width_t width, eb_address_t addr) {
  struct sdwb_device_descriptor device_descriptor;
  
  device_descriptor.vendor          = htobe64(device->vendor);
  device_descriptor.device          = htobe32(device->device);
  device_descriptor.wbd_granularity = device->wbd_granularity;
  device_descriptor.wbd_width       = device->wbd_width;
  device_descriptor.wbd_ver_major   = device->wbd_ver_major;
  device_descriptor.wbd_ver_minor   = device->wbd_ver_minor;
  device_descriptor.hdl_base        = htobe64(device->hdl_base);
  device_descriptor.hdl_size        = htobe64(device->hdl_size);
  device_descriptor.wbd_flags       = htobe32(device->wbd_flags);
  device_descriptor.hdl_class       = htobe32(device->hdl_class);
  device_descriptor.hdl_version     = htobe32(device->hdl_version);
  device_descriptor.hdl_date        = htobe32(device->hdl_date);
  memcpy(&device_descriptor.vendor_name[0], &device->vendor_name[0], 16);
  memcpy(&device_descriptor.device_name[0], &device->device_name[0], 16);
  
  return eb_sdwb_extract(&device_descriptor, width, addr);
}

eb_data_t eb_sdwb(eb_socket_t socketp, eb_width_t width, eb_address_t addr) {
  struct eb_socket* socket;
  struct eb_handler_address* address;
  eb_handler_address_t addressp;
  int dev;
  
  socket = EB_SOCKET(socketp);
  
  /* Memory map:
   *   0x000   - Header
   *   0x020   - ID Block
   *   0x040   - First Descriptor
   *   0x090   - Second Descriptor
   *   ...
   */
  if (addr < 0x20) {
    /* Count the devices */
    dev = 0;
    for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
      address = EB_HANDLER_ADDRESS(addressp);
      ++dev;
    }
    return eb_sdwb_header(width, addr, dev);
  }
  
  if (addr < 0x40) return eb_sdwb_id_block(width, addr - 0x20);
  
  addr -= 0x40;
  dev = addr / 0x50;
  addr %= 0x50;
  
  for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
    address = EB_HANDLER_ADDRESS(addressp);
    if (dev-- == 0) break;
  }
  
  if (addressp == EB_NULL) return 0;
  return eb_sdwb_device(address->device, width, addr);
}
