/** @file eb-ls.c
 *  @brief A tool which lists all devices attached to a remote Wishbone bus.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  A complete skeleton of an application using the Etherbone library.
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

#define _POSIX_C_SOURCE 200112L /* strtoull */

#include <stdio.h>
#include <stdlib.h>
#include "../etherbone.h"

static void list_devices(eb_user_data_t user, sdwb_t sdwb, eb_status_t status) {
  int i, devices;
  int* stop = (int*)user;
  *stop = 1;
  
  if (status != EB_OK) {
    fprintf(stderr, "Failed to retrieve SDWB: %s\n", eb_status(status));
    return;
  } 
  
  fprintf(stdout, "SDWB Header\n");
  fprintf(stdout, "  magic:      %02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x\n", 
                  sdwb->header.magic[0], sdwb->header.magic[1],
                  sdwb->header.magic[2], sdwb->header.magic[3],
                  sdwb->header.magic[4], sdwb->header.magic[5],
                  sdwb->header.magic[6], sdwb->header.magic[7]);
  fprintf(stdout, "  wbidb_addr: %016"PRIx64"\n", sdwb->header.wbidb_addr);
  fprintf(stdout, "  wbddb_addr: %016"PRIx64"\n", sdwb->header.wbddb_addr);
  fprintf(stdout, "  wbddb_size: %016"PRIx64"\n", sdwb->header.wbddb_size);
  fprintf(stdout, "\n");
  
  fprintf(stdout, "ID Block\n");
  fprintf(stdout, "  bitstream_devtype: %016"PRIx64"\n", sdwb->id_block.bitstream_devtype);
  fprintf(stdout, "  bitstream_version: %08"PRIx32"\n", sdwb->id_block.bitstream_version);
  fprintf(stdout, "  bitstream_date:    %08"PRIx32"\n", sdwb->id_block.bitstream_date);
  fprintf(stdout, "  bitstream_source:  %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x\n",
                  sdwb->id_block.bitstream_source[ 0], sdwb->id_block.bitstream_source[ 1], 
                  sdwb->id_block.bitstream_source[ 2], sdwb->id_block.bitstream_source[ 3], 
                  sdwb->id_block.bitstream_source[ 4], sdwb->id_block.bitstream_source[ 5], 
                  sdwb->id_block.bitstream_source[ 6], sdwb->id_block.bitstream_source[ 7], 
                  sdwb->id_block.bitstream_source[ 8], sdwb->id_block.bitstream_source[ 9], 
                  sdwb->id_block.bitstream_source[10], sdwb->id_block.bitstream_source[11], 
                  sdwb->id_block.bitstream_source[12], sdwb->id_block.bitstream_source[13], 
                  sdwb->id_block.bitstream_source[14], sdwb->id_block.bitstream_source[15]);
  fprintf(stdout, "\n");

  devices = sdwb->header.wbddb_size / 80;
  for (i = 0; i < devices; ++i) {
    sdwb_device_descriptor_t des = &sdwb->device_descriptor[i];
    
    if ((des->wbd_flags & WBD_FLAG_PRESENT) == 0) {
      fprintf(stdout, "Device %d: not present\n", i);
      continue;
    }
    
    fprintf(stdout, "Device %d\n", i);
    fprintf(stdout, "  vendor:          %016"PRIx64"\n", des->vendor);
    fprintf(stdout, "  device:          %08"PRIx32"\n", des->device);
    fprintf(stdout, "  wbd_width:       %d\n", des->wbd_width);
    fprintf(stdout, "  wbd_ver_major:   %d\n", des->wbd_ver_major);
    fprintf(stdout, "  wbd_ver_minor:   %d\n", des->wbd_ver_minor);
    fprintf(stdout, "  hdl_base:        %016"PRIx64"\n", des->hdl_base);
    fprintf(stdout, "  hdl_size:        %016"PRIx64"\n", des->hdl_size);
    fprintf(stdout, "  wbd_flags:       %08"PRIx32"\n", des->wbd_flags);
    fprintf(stdout, "  hdl_class:       %08"PRIx32"\n", des->hdl_class);
    fprintf(stdout, "  hdl_version:     %08"PRIx32"\n", des->hdl_version);
    fprintf(stdout, "  hdl_date:        %08"PRIx32"\n", des->hdl_date);
    fprintf(stdout, "  vendor_name:     "); fwrite(des->vendor_name, 1, 16, stdout); fprintf(stdout, "\n");
    fprintf(stdout, "  device_name:     "); fwrite(des->device_name, 1, 16, stdout); fprintf(stdout, "\n");
  }
}

int main(int argc, const char** argv) {
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  int stop;
  
  if (argc != 2) {
    fprintf(stderr, "Syntax: %s <protocol/host/port>\n", argv[0]);
    return 1;
  }
  
  if ((status = eb_socket_open(EB_ABI_CODE, 0, EB_DATAX|EB_ADDRX, &socket)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_device_open(socket, argv[1], EB_ADDRX|EB_DATAX, 3, &device)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone device: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_sdwb_scan(device, &stop, &list_devices)) != EB_OK) {
    fprintf(stderr, "Failed to scan remote device: %s\n", eb_status(status));
    return 1;
  }
  
  stop = 0;
  while (!stop) {
    eb_device_flush(device);
    eb_socket_block(socket, -1);
    eb_socket_poll(socket);
  }
  
  if ((status = eb_device_close(device)) != EB_OK) {
    fprintf(stderr, "Failed to close Etherbone device: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_socket_close(socket)) != EB_OK) {
    fprintf(stderr, "Failed to close Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  return 0;
}
