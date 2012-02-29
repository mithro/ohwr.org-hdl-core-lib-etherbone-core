/** @file eb-read.c
 *  @brief A demonstration program which executes an Etherbone read.
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

static void set_stop(eb_user_data_t user, eb_operation_t op, eb_status_t status) {
  int* stop = (int*)user;
  *stop = 1;
  
  if (status != EB_OK) {
    fprintf(stdout, "%s\n", eb_status(status));
  } else {
    if (eb_operation_had_error(op))
      fprintf(stdout, " <<-- wishbone segfault -->>\n");
    else
      fprintf(stdout, "%016"EB_DATA_FMT".\n", eb_operation_data(op));
  }
}

int main(int argc, const char** argv) {
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  eb_width_t width;
  eb_format_t format;
  eb_cycle_t cycle;
  eb_address_t address;
  const char* netaddress;
  int stop;
  
  if (argc < 3 || argc > 4) {
    fprintf(stderr, "Syntax: %s <protocol/host/port> <address> [width]\n", argv[0]);
    return 1;
  }
  
  netaddress = argv[1];
  address = strtoull(argv[2], 0, 0);
  
  if (argc == 4)
    format = strtoul(argv[3], 0, 0);
  else
    format = EB_DATAX;
  
  if ((status = eb_socket_open(0, EB_DATAX|EB_ADDRX, &socket)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_device_open(socket, netaddress, EB_ADDRX|EB_DATAX, 3, &device)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone device: %s\n", eb_status(status));
    return 1;
  }
  
  width = eb_device_width(device);
  fprintf(stdout, "Connected to %s with %d/%d-bit address/port widths\n\n", netaddress, (width >> 4) * 8, (width & EB_DATAX) * 8);
  
  fprintf(stdout, "Reading at %016"EB_ADDR_FMT": ", address);
  fflush(stdout);
  
  if ((cycle = eb_cycle_open(device, &stop, &set_stop)) == EB_NULL) {
    fprintf(stderr, "out of memory\n");
    return 1;
  }
  
  eb_cycle_read(cycle, address, format, 0);
  eb_cycle_close(cycle);

  stop = 0;
  eb_device_flush(device);
  while (!stop) {
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
