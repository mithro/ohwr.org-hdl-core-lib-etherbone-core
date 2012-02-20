/** @file eb-write.c
 *  @brief A demonstration program which executes an Etherbone write.
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
#include "../etherbone.h"

int main(int argc, const char** argv) {
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  eb_cycle_t cycle;
  eb_address_t address;
  eb_data_t data;
  const char* netaddress;
  
  if (argc != 4) {
    fprintf(stderr, "Syntax: %s <protocol/host/port> <address> <data>\n", argv[0]);
    return 1;
  }
  
  netaddress = argv[1];
  address = strtoll(argv[2], 0, 0);
  data = strtoll(argv[3], 0, 0);
  
  if ((status = eb_socket_open(0, EB_DATAX|EB_ADDRX, &socket)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_device_open(socket, netaddress, EB_ADDRX|EB_DATAX, 3, &device)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone device: %s\n", eb_status(status));
    return 1;
  }
  
  fprintf(stdout, "Writing to device %s at %08"EB_ADDR_FMT": %08"EB_DATA_FMT": ", netaddress, address, data);
  fflush(stdout);
  
  if ((cycle = eb_cycle_open(device, 0, 0)) == EB_NULL) {
    fprintf(stdout, "out of memory\n");
    return 1;
  }
  
  eb_cycle_write(cycle, address, EB_DATAX, data);
  eb_cycle_close_silently(cycle); /* silently means we don't care about the ERR flag */
  eb_device_flush(device); /* flush queued data out the device */
  fprintf(stdout, "ok\n");
  
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
