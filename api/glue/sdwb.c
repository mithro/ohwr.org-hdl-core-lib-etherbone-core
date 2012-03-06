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

/* Obtained from www.random.org: */
static uint8_t eb_sdwb_magic[16] = { 0x40, 0xf6, 0xe9, 0x8c, 0x29, 0xea, 0xe2, 0x4c, 0x7e, 0x64, 0x61, 0xae, 0x8d, 0x2a, 0xf2, 0x47 };
/* We actually use the bit-inverse of these bytes so that magic does not appear in our executable image */

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

static eb_data_t eb_sdwb_bus(eb_width_t width, eb_address_t addr, int devices) {
  static const char date[50]     = "$Date::                                          $";
  static const char revision[20] = "$Rev::             $";
  
  struct sdwb_bus bus;
  const char* s;
  uint32_t version_v, date_v;
  eb_data_t out;
  int i;
  
  date_v = 
    (((uint32_t)(date[ 8]-'0'))<<28)|(((uint32_t)(date[ 9]-'0'))<<24)|
    (((uint32_t)(date[10]-'0'))<<20)|(((uint32_t)(date[11]-'0'))<<16)|
    (((uint32_t)(date[13]-'0'))<<12)|(((uint32_t)(date[14]-'0'))<< 8)|
    (((uint32_t)(date[16]-'0'))<< 4)|(((uint32_t)(date[17]-'0'))<< 0);
  
  version_v = 0;
  for (s = &revision[7]; *s != ' '; ++s) {
    version_v *= 10;
    version_v += *s - '0';
  }
  
  bus.bus_end        = htobe64(~(eb_address_t)0);
  bus.sdwb_records   = htobe16(devices+1);
  bus.sdwb_ver_major = 1;
  bus.sdwb_ver_minor = 0;
  bus.bus_vendor     = 0x651; /* GSI */
  bus.bus_device     = 0x1;
  bus.bus_version    = htobe32(version_v << 16 | EB_ABI_VERSION);
  bus.bus_date       = htobe32(date_v);
  bus.bus_flags      = 0;
  
  memcpy(&bus.description[0], "Software-EB-Bus ", 16);

  /* Fill in the magic */
  for (i = 0; i < 16; ++i) bus.magic[i] = ~eb_sdwb_magic[i];
  /* Extract the value needed */
  out = eb_sdwb_extract(&bus, width, addr);
  /* Destroy the magic from main memory */
  memset(&bus.magic, 0, 16);
  
  return out;
}

static eb_data_t eb_sdwb_device(sdwb_device_t device, eb_width_t width, eb_address_t addr) {
  struct sdwb_device dev;
  
  dev.wbd_begin       = htobe64(device->wbd_begin);
  dev.wbd_end         = htobe64(device->wbd_end);
  dev.sdwb_child      = htobe64(device->sdwb_child);
  dev.wbd_flags       = device->wbd_flags;
  dev.wbd_width       = device->wbd_width;
  dev.abi_ver_major   = device->abi_ver_major;
  dev.abi_ver_minor   = device->abi_ver_minor;
  dev.abi_class       = htobe32(device->abi_class);
  dev.dev_vendor      = htobe32(device->dev_vendor);
  dev.dev_device      = htobe32(device->dev_device);
  dev.dev_version     = htobe32(device->dev_version);
  dev.dev_date        = htobe32(device->dev_date);
  memcpy(&dev.description[0], &device->description[0], 16);
  
  return eb_sdwb_extract(&dev, width, addr);
}

eb_data_t eb_sdwb(eb_socket_t socketp, eb_width_t width, eb_address_t addr) {
  struct eb_socket* socket;
  struct eb_handler_address* address;
  eb_handler_address_t addressp;
  int dev;
  
  socket = EB_SOCKET(socketp);
  
  if (addr < 0x40) {
    /* Count the devices */
    dev = 0;
    for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
      address = EB_HANDLER_ADDRESS(addressp);
      ++dev;
    }
    return eb_sdwb_bus(width, addr, dev);
  }
  
  dev = addr >> 6;
  addr &= 0x3f;
  
  for (addressp = socket->first_handler; addressp != EB_NULL; addressp = address->next) {
    address = EB_HANDLER_ADDRESS(addressp);
    if (--dev == 0) break;
  }
  
  if (addressp == EB_NULL) return 0;
  return eb_sdwb_device(address->device, width, addr);
}

static int eb_sdwb_fill_block(uint8_t* ptr, uint16_t max_len, eb_operation_t ops) {
  eb_data_t data;
  uint8_t* eptr;
  int i, stride;
  
  for (eptr = ptr + max_len; ops != EB_NULL; ops = eb_operation_next(ops)) {
    if (eb_operation_had_error(ops)) return -1;
    data = eb_operation_data(ops);
    stride = eb_operation_format(ops) & EB_DATAX;
    
    /* More data follows */
    if (eptr-ptr < stride) return 1;
    
    for (i = stride-1; i >= 0; --i) {
      ptr[i] = data & 0xFF;
      data >>= 8;
    }
    ptr += stride;
  }
  
  return 0;
}

static void eb_sdwb_decode(struct eb_sdwb_scan* scan, eb_device_t device, uint8_t* buf, uint16_t size, eb_operation_t ops) {
  eb_user_data_t data;
  sdwb_callback_t cb;
  eb_address_t bus_base;
  sdwb_t sdwb;
  uint16_t i;
  
  cb = scan->cb;
  data = scan->user_data;
  bus_base = scan->bus_base;
  
  if (eb_sdwb_fill_block(buf, size, ops) != 0) {
    (*cb)(data, device, 0, EB_FAIL);
    return;
  }
  
  sdwb = (sdwb_t)buf;
  
  /* Bus endian fixup */
  sdwb->bus.bus_end      = bus_base + be64toh(sdwb->bus.bus_end);
  sdwb->bus.sdwb_records = be16toh(sdwb->bus.sdwb_records);
  sdwb->bus.bus_vendor   = be32toh(sdwb->bus.bus_vendor);
  sdwb->bus.bus_device   = be32toh(sdwb->bus.bus_device);
  sdwb->bus.bus_version  = be32toh(sdwb->bus.bus_version);
  sdwb->bus.bus_date     = be32toh(sdwb->bus.bus_date);
  sdwb->bus.bus_flags    = be32toh(sdwb->bus.bus_flags);
  
  if (sizeof(struct sdwb_device) * sdwb->bus.sdwb_records < size) {
    (*cb)(data, device, 0, EB_FAIL);
    return;
  }
  
  /* Descriptor blocks */
  for (i = 0; i < sdwb->bus.sdwb_records-1; ++i) {
    sdwb_device_t dd = &sdwb->device[i];
    
    dd->wbd_begin   = bus_base + be64toh(dd->wbd_begin);
    dd->wbd_end     = bus_base + be64toh(dd->wbd_end);
    dd->sdwb_child  = bus_base + be64toh(dd->sdwb_child);
    dd->abi_class   = be32toh(dd->abi_class);
    dd->dev_vendor  = be32toh(dd->dev_vendor);
    dd->dev_device  = be32toh(dd->dev_device);
    dd->dev_version = be32toh(dd->dev_version);
    dd->dev_date    = be32toh(dd->dev_date);
  }
  
  (*cb)(data, device, sdwb, EB_OK);
  
  /* Remove the magic from main memory */
  memset(&sdwb->bus.magic[0], 0, 16);
}

/* We allocate buffer on the stack to hack around missing alloca */
#define EB_SDWB_DECODE(x)                                                                          \
static void eb_sdwb_decode##x(struct eb_sdwb_scan* scan, eb_device_t device, eb_operation_t ops) { \
  union {                                                                                          \
    struct {                                                                                       \
      struct sdwb_bus    bus;                                                                      \
      struct sdwb_device device[x];                                                                \
    } s;                                                                                           \
    uint8_t bytes[1];                                                                              \
  } sdwb;                                                                                          \
  return eb_sdwb_decode(scan, device, &sdwb.bytes[0], sizeof(sdwb), ops);                          \
}

EB_SDWB_DECODE(4)
EB_SDWB_DECODE(8)
EB_SDWB_DECODE(16)
EB_SDWB_DECODE(32)
EB_SDWB_DECODE(64)
EB_SDWB_DECODE(128)
EB_SDWB_DECODE(256)

static void eb_sdwb_got_all(eb_user_data_t mydata, eb_device_t device, eb_operation_t ops, eb_status_t status) {
  union {
    struct sdwb_bus s;
    uint8_t bytes[1];
  } header;
  struct eb_sdwb_scan* scan;
  eb_sdwb_scan_t scanp;
  eb_user_data_t data;
  sdwb_callback_t cb;
  uint16_t devices;
  
  scanp = (eb_sdwb_scan_t)(uintptr_t)mydata;
  scan = EB_SDWB_SCAN(scanp);
  cb = scan->cb;
  data = scan->user_data;
  
  if (status != EB_OK) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, device, 0, status);
    return;
  }
  
  if (eb_sdwb_fill_block(&header.bytes[0], sizeof(header), ops) != 1) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, device, 0, EB_FAIL);
    return;
  }
  
  devices = be16toh(header.s.sdwb_records) - 1;
  
  if      (devices <   4) eb_sdwb_decode4(scan, device, ops);
  else if (devices <   8) eb_sdwb_decode8(scan, device, ops);
  else if (devices <  16) eb_sdwb_decode16(scan, device, ops);
  else if (devices <  32) eb_sdwb_decode32(scan, device, ops);
  else if (devices <  64) eb_sdwb_decode64(scan, device, ops);
  else if (devices < 128) eb_sdwb_decode128(scan, device, ops);
  else if (devices < 256) eb_sdwb_decode256(scan, device, ops);
  else (*cb)(data, device, 0, EB_OOM);
  
  eb_free_sdwb_scan(scanp);
}  

static void eb_sdwb_got_header(eb_user_data_t mydata, eb_device_t device, eb_operation_t ops, eb_status_t status) {
  union {
    struct sdwb_bus s;
    uint8_t bytes[1];
  } header;
  struct eb_sdwb_scan* scan;
  eb_sdwb_scan_t scanp;
  eb_user_data_t data;
  sdwb_callback_t cb;
  eb_address_t address, end;
  eb_cycle_t cycle;
  int stride, i;
  
  scanp = (eb_sdwb_scan_t)(uintptr_t)mydata;
  scan = EB_SDWB_SCAN(scanp);
  cb = scan->cb;
  data = scan->user_data;
  
  stride = (eb_device_width(device) & EB_DATAX);
  
  if (status != EB_OK) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, device, 0, status);
    return;
  }
  
  /* Read in the header */
  if (eb_sdwb_fill_block(&header.bytes[0], sizeof(header), ops) != 0) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, device, 0, EB_FAIL);
    return;
  }
  
  /* Is the magic there? */
  for (i = 0; i < 16; ++i)
    if ((header.s.magic[i] ^ eb_sdwb_magic[i]) != 0xff) {
      eb_free_sdwb_scan(scanp);
      (*cb)(data, device, 0, EB_FAIL);
      return;
    }
  
  /* Clear the magic from memory */
  memset(&header.s.magic[0], 0, 16);
  
  /* Now, we need to read: entire table */
  if ((cycle = eb_cycle_open(device, (eb_user_data_t)(uintptr_t)scanp, &eb_sdwb_got_all)) == EB_NULL) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, device, 0, EB_OOM);
    return;
  }
  
  /* Read: header again */
  address = eb_operation_address(ops);
  for (end = address + (((eb_address_t)be16toh(header.s.sdwb_records)) << 6); address < end; address += stride)
    eb_cycle_read(cycle, address, EB_DATAX, 0);
  
  eb_cycle_close(cycle);
  eb_device_flush(device);
}

eb_status_t eb_sdwb_scan_bus(eb_device_t device, sdwb_device_t bridge, eb_user_data_t data, sdwb_callback_t cb) {
  struct eb_sdwb_scan* scan;
  eb_cycle_t cycle;
  eb_sdwb_scan_t scanp;
  int stride;
  eb_address_t header_address;
  eb_address_t header_end;
  
  if ((bridge->wbd_flags & WBD_FLAG_HAS_CHILD) == 0)
    return EB_ADDRESS;
  
  if ((scanp = eb_new_sdwb_scan()) == EB_NULL)
    return EB_OOM;
  
  scan = EB_SDWB_SCAN(scanp);
  scan->cb = cb;
  scan->user_data = data;
  scan->bus_base = bridge->wbd_begin;
  
  stride = (eb_device_width(device) & EB_DATAX);
  
  /* scan invalidated by all the EB calls below (which allocate) */
  if ((cycle = eb_cycle_open(device, (eb_user_data_t)(uintptr_t)scanp, &eb_sdwb_got_header)) == EB_NULL) {
    eb_free_sdwb_scan(scanp);
    return EB_OOM;
  }
  
  header_address = bridge->sdwb_child;
  for (header_end = header_address + 32; header_address < header_end; header_address += stride)
    eb_cycle_read(cycle, header_address, EB_DATAX, 0);
  
  eb_cycle_close(cycle);
  eb_device_flush(device);
  
  return EB_OK;
}

static void eb_sdwb_got_header_ptr(eb_user_data_t mydata, eb_device_t device, eb_operation_t ops, eb_status_t status) {
  struct eb_sdwb_scan* scan;
  eb_sdwb_scan_t scanp;
  eb_user_data_t data;
  eb_address_t header_address;
  eb_address_t header_end;
  sdwb_callback_t cb;
  eb_cycle_t cycle;
  int stride;
  
  scanp = (eb_sdwb_scan_t)(uintptr_t)mydata;
  scan = EB_SDWB_SCAN(scanp);
  cb = scan->cb;
  data = scan->user_data;
  
  stride = (eb_device_width(device) & EB_DATAX);
  
  if (status != EB_OK) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, device, 0, status);
    return;
  }
  
  /* Calculate the address from partial reads */
  header_address = 0;
  for (; ops != EB_NULL; ops = eb_operation_next(ops)) {
    if (eb_operation_had_error(ops)) {
      eb_free_sdwb_scan(scanp);
      (*cb)(data, device, 0, EB_FAIL);
      return;
    }
    header_address <<= (stride*8);
    header_address += eb_operation_data(ops);
  }
  
  /* Now, we need to read the header */
  if ((cycle = eb_cycle_open(device, (eb_user_data_t)(uintptr_t)scanp, &eb_sdwb_got_header)) == EB_NULL) {
    eb_free_sdwb_scan(scanp);
    (*cb)(data, device, 0, EB_OOM);
    return;
  }
  
  for (header_end = header_address + 32; header_address < header_end; header_address += stride)
    eb_cycle_read(cycle, header_address, EB_DATAX, 0);
  
  eb_cycle_close(cycle);
  eb_device_flush(device);
}

eb_status_t eb_sdwb_scan_root(eb_device_t device, eb_user_data_t data, sdwb_callback_t cb) {
  struct eb_sdwb_scan* scan;
  eb_cycle_t cycle;
  eb_sdwb_scan_t scanp;
  int addr, stride;
  
  if ((scanp = eb_new_sdwb_scan()) == EB_NULL)
    return EB_OOM;
  
  scan = EB_SDWB_SCAN(scanp);
  scan->cb = cb;
  scan->user_data = data;
  scan->bus_base = 0;
  
  stride = (eb_device_width(device) & EB_DATAX);
  
  /* scan invalidated by all the EB calls below (which allocate) */
  if ((cycle = eb_cycle_open(device, (eb_user_data_t)(uintptr_t)scanp, &eb_sdwb_got_header_ptr)) == EB_NULL) {
    eb_free_sdwb_scan(scanp);
    return EB_OOM;
  }
  
  for (addr = 8; addr < 16; addr += stride)
    eb_cycle_read_config(cycle, addr, EB_DATAX, 0);
  
  eb_cycle_close(cycle);
  eb_device_flush(device);
  
  return EB_OK;
}
