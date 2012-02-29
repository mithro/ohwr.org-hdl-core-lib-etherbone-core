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
#define EB_NEED_BIGENDIAN_64 1

#include "socket.h"
#include "sdwb.h"
#include "../format/bigendian.h"
#include "../memory/memory.h"

#include <string.h>
#include <alloca.h>

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

static int eb_sdwb_fill_block(uint8_t* ptr, int stride, eb_operation_t ops) {
  eb_data_t data;
  int i;
  
  for (; ops != EB_NULL; ops = eb_operation_next(ops)) {
    if (eb_operation_had_error(ops)) return -1;
    data = eb_operation_data(ops);
    
    for (i = stride-1; i >= 0; --i) {
      ptr[i] = data & 0xFF;
      data >>= 8;
    }
    ptr += stride;
  }
  
  return 0;
}

static void eb_sdwb_decode(struct eb_sdwb_scan* scan, uint8_t* buf, eb_operation_t ops) {
  eb_device_t device;
  eb_user_data_t data;
  sdwb_callback_t cb;
  int stride;
  uint16_t i, devices;
  sdwb_t sdwb;
  
  device = scan->device;
  cb = scan->cb;
  data = scan->user_data;
  devices = scan->devices;
  stride = (eb_device_width(device) & EB_DATAX);
  
  if (eb_sdwb_fill_block(buf, stride, ops) < 0) {
    (*cb)(data, 0, EB_FAIL);
    return;
  }
  
  sdwb = (sdwb_t)buf;
  
  /* Header endian */
  sdwb->header.wbidb_addr = be64toh(sdwb->header.wbidb_addr);
  sdwb->header.wbddb_addr = be64toh(sdwb->header.wbddb_addr);
  sdwb->header.wbddb_size = be64toh(sdwb->header.wbddb_size);
  
  /* ID block endian */
  sdwb->id_block.bitstream_devtype = be64toh(sdwb->id_block.bitstream_devtype);
  sdwb->id_block.bitstream_version = be32toh(sdwb->id_block.bitstream_version);
  sdwb->id_block.bitstream_date    = be32toh(sdwb->id_block.bitstream_date);
  
  /* Descriptor blocks */
  for (i = 0; i < devices; ++i) {
    sdwb_device_descriptor_t dd = &sdwb->device_descriptor[i];
    
    dd->vendor      = be64toh(dd->vendor);
    dd->device      = be32toh(dd->device);
    dd->hdl_base    = be64toh(dd->hdl_base);
    dd->hdl_size    = be64toh(dd->hdl_size);
    dd->wbd_flags   = be32toh(dd->wbd_flags);
    dd->hdl_class   = be32toh(dd->hdl_class);
    dd->hdl_version = be32toh(dd->hdl_version);
    dd->hdl_date    = be32toh(dd->hdl_date);
  }
  
  (*cb)(data, sdwb, EB_OK);
}

static void eb_sdwb_got_all(eb_user_data_t mydata, eb_operation_t ops, eb_status_t status) {
  struct eb_sdwb_scan* scan;
  eb_sdwb_scan_t scanp;
  eb_user_data_t data;
  sdwb_callback_t cb;
  uint16_t devices;
  uint8_t* buf;
  
  scanp = (eb_sdwb_scan_t)(uintptr_t)mydata;
  scan = EB_SDWB_SCAN(scanp);
  cb = scan->cb;
  data = scan->user_data;
  devices = scan->devices;
  
  if (status != EB_OK) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, 0, status);
    return;
  }
  
  /* Use trick !!! */
  buf = alloca(32+32+80*devices);
  eb_sdwb_decode(scan, buf, ops);
  eb_free_sdwb_scan(scanp);
}  

static void eb_sdwb_got_header(eb_user_data_t mydata, eb_operation_t ops, eb_status_t status) {
  union {
    struct sdwb_header s;
    uint8_t bytes[1];
  } header;
  struct eb_sdwb_scan* scan;
  eb_sdwb_scan_t scanp;
  eb_device_t device;
  eb_user_data_t data;
  sdwb_callback_t cb;
  eb_address_t address, end;
  eb_cycle_t cycle;
  int stride;
  
  scanp = (eb_sdwb_scan_t)(uintptr_t)mydata;
  scan = EB_SDWB_SCAN(scanp);
  device = scan->device;
  cb = scan->cb;
  data = scan->user_data;
  stride = (eb_device_width(device) & EB_DATAX);
  
  if (status != EB_OK) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, 0, status);
    return;
  }
  
  /* Read in the header */
  if (eb_sdwb_fill_block(&header.bytes[0], stride, ops) < 0) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, 0, EB_FAIL);
    return;
  }
  
  /* scan is still valid because eb_operation_* do not allocate */
  scan->devices = be64toh(header.s.wbddb_size) / 80;
  
  /* Now, we need to read: header, id block, device descriptors */
  if ((cycle = eb_cycle_open(device, (eb_user_data_t)(uintptr_t)scanp, &eb_sdwb_got_all)) == EB_NULL) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, 0, EB_OOM);
    return;
  }
  
  /* Read: header again */
  address = eb_operation_address(ops);
  for (end = address + 32; address < end; address += stride)
    eb_cycle_read(cycle, address, EB_DATAX, 0);
  
  /* Read the ID block */
  address = be64toh(header.s.wbidb_addr);
  for (end = address + 32; address < end; address += stride)
    eb_cycle_read(cycle, address, EB_DATAX, 0);

  /* Read the descriptors */
  address = be64toh(header.s.wbddb_addr);
  for (end = address + be64toh(header.s.wbddb_size); address < end; address += stride)
    eb_cycle_read(cycle, address, EB_DATAX, 0);
  
  eb_cycle_close(cycle);
}

static void eb_sdwb_got_header_ptr(eb_user_data_t mydata, eb_operation_t ops, eb_status_t status) {
  struct eb_sdwb_scan* scan;
  eb_sdwb_scan_t scanp;
  eb_device_t device;
  eb_user_data_t data;
  eb_address_t header_address;
  eb_address_t header_end;
  sdwb_callback_t cb;
  eb_cycle_t cycle;
  int stride;
  
  scanp = (eb_sdwb_scan_t)(uintptr_t)mydata;
  scan = EB_SDWB_SCAN(scanp);
  device = scan->device;
  cb = scan->cb;
  data = scan->user_data;
  stride = (eb_device_width(device) & EB_DATAX);
  
  if (status != EB_OK) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, 0, status);
    return;
  }
  
  /* Calculate the address from partial reads */
  header_address = 0;
  for (; ops != EB_NULL; ops = eb_operation_next(ops)) {
    if (eb_operation_had_error(ops)) {
      eb_free_sdwb_scan(scanp);
      (*cb)(data, 0, EB_FAIL);
      return;
    }
    header_address <<= (stride*8);
    header_address += eb_operation_data(ops);
  }
  
  /* Now, we need to read the header */
  if ((cycle = eb_cycle_open(device, (eb_user_data_t)(uintptr_t)scanp, &eb_sdwb_got_header)) == EB_NULL) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, 0, EB_OOM);
    return;
  }
  
  for (header_end = header_address + 32; header_address < header_end; header_address += stride)
    eb_cycle_read(cycle, header_address, EB_DATAX, 0);
  
  eb_cycle_close(cycle);
}

eb_status_t eb_sdwb_scan(eb_device_t device, eb_user_data_t data, sdwb_callback_t cb) {
  struct eb_sdwb_scan* scan;
  eb_cycle_t cycle;
  eb_sdwb_scan_t scanp;
  int addr, stride;
  
  if ((scanp = eb_new_sdwb_scan()) == EB_NULL)
    return EB_OOM;
  
  scan = EB_SDWB_SCAN(scanp);
  scan->device = device;
  scan->cb = cb;
  scan->user_data = data;
  stride = (eb_device_width(device) & EB_DATAX);
  
  /* scan invalidated by all the EB calls below (which allocate) */
  if ((cycle = eb_cycle_open(device, (eb_user_data_t)(uintptr_t)scanp, &eb_sdwb_got_header_ptr)) == EB_NULL) {
    eb_free_sdwb_scan(scanp);
    return EB_OOM;
  }
  
  for (addr = 8; addr < 16; addr += stride)
    eb_cycle_read_config(cycle, addr, EB_DATAX, 0);
  
  eb_cycle_close(cycle);
  return EB_OK;
}
