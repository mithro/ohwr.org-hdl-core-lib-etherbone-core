/** @file eb-load.c
 *  @brief A demonstration program which loads a file to a device.
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "../etherbone.h"

void set_ok(eb_user_data_t data, eb_operation_t ops, eb_status_t status);
void set_ok(eb_user_data_t data, eb_operation_t ops, eb_status_t status) {
  int* ok;
  
  /* Check overall status */
  if (status != EB_OK) {
    fprintf(stderr, "\nEB cycle failure: %s\n", eb_status(status));
    exit(1);
  }
  
  /* Check operation error lines */
  for (; ops != EB_NULL; ops = eb_operation_next(ops)) {
    if (eb_operation_had_error(ops)) {
      fprintf(stderr, "\nRemote segfault writing %016"EB_DATA_FMT" to address %016"EB_ADDR_FMT".\n",
        eb_operation_data(ops), eb_operation_address(ops));
      exit(1);
    }
  }
  
  ok = (int*)data;
  *ok = 1;
}

int main(int argc, const char** argv) {
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  eb_cycle_t cycle;
  eb_address_t address;
  eb_width_t width;
  eb_data_t data;
  const char* netaddress;
  const char* firmware;
  uint8_t buffer[1024];
  int i, j, len, stride, ok;
  FILE* file;
  
  if (argc != 4) {
    fprintf(stderr, "Syntax: %s <etherbone-address> <file> <base-address>\n", argv[0]);
    return 1;
  }
  
  netaddress = argv[1];
  firmware = argv[2];
  address = strtoll(argv[3], 0, 0);
  
  if ((file = fopen(firmware, "r")) == 0) {
    fprintf(stderr, "Failed to open %s: %s\n", firmware, strerror(errno));
    return 1;
  }
  
  if ((status = eb_socket_open(0, EB_DATAX|EB_ADDRX, &socket)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_device_open(socket, netaddress, EB_ADDRX|EB_DATAX, 3, &device)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone device: %s\n", eb_status(status));
    return 1;
  }
  
  width = eb_device_widths(device);
  stride = width & EB_DATAX;
  fprintf(stdout, "Remote device is %d bits wide.\n", stride*8);
  
  while ((len = fread(buffer, 1, sizeof(buffer), file)) > 0) {
    printf("\rWriting to address %016"EB_ADDR_FMT"... ", address);
    fflush(stdout);
    
    if ((cycle = eb_cycle_open(device, &ok, &set_ok)) == EB_NULL) {
      fprintf(stderr, "Cannot create cycle: out of memory\n");
      return 1;
    }
    
    if (len % stride != 0) {
      fprintf(stderr, "Input file is not %d-aligned.\n", stride*8);
      return 1;
    }
    
    for (i = 0; i < len; i += stride) {
      data = 0;
      /* Bigendian... perhaps make configurable */
      for (j = 0; j < stride; ++j)
        data = (data << 8) | buffer[i+j];
      
      eb_cycle_write(cycle, address, data);
      address += stride;
    }
    
    eb_cycle_close(cycle);
    eb_device_flush(device);
    
    ok = 0;
    while (!ok) {
      eb_socket_block(socket, 0);
      eb_socket_poll(socket);
    }
  }
  
  printf("done!\n");
  
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
