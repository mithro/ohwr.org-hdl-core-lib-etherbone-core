/** @file eb-snoop.c
 *  @brief A demonstration program which captures Etherbone bus access.
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

static uint8_t my_memory[256];

static eb_status_t my_read(eb_user_data_t user, eb_address_t address, eb_width_t width, eb_data_t* data) {
  eb_data_t out;
  
  fprintf(stdout, "Received read to address %016"EB_ADDR_FMT" of %d bits\n", address, (width&EB_DATAX)*8);
  
  /* Software slaves must be bigendian */
  out = 0;
  for (width &= EB_DATAX; width > 0; --width) {
    out <<= 8;
    out |= my_memory[address++ & 0xff];
  }
  
  *data = out;
  return EB_OK;
}

static eb_status_t my_write(eb_user_data_t user, eb_address_t address, eb_width_t width, eb_data_t data) {
  fprintf(stdout, "Received write to address %016"EB_ADDR_FMT" of %d bits: %016"EB_DATA_FMT"\n", address, (width&EB_DATAX)*8, data);
  
  /* Software slaves must be bigendian */
  for (width &= EB_DATAX; width > 0; --width) {
    my_memory[(address+width-1)&0xff] = data & 0xff;
    data >>= 8;
  }
  
  return EB_OK;
}

int main(int argc, const char** argv) {
  struct eb_handler handler;
  const char* port;
  eb_status_t status;
  eb_socket_t socket;
  int i;
  
  if (argc != 4) {
    fprintf(stderr, "Syntax: %s <port> <address> <mask>\n", argv[0]);
    return 1;
  }
  
  port = argv[1];
  handler.base = strtoull(argv[2], 0, 0);
  handler.mask = strtoull(argv[3], 0, 0);
  
  handler.data = 0;
  handler.read = &my_read;
  handler.write = &my_write;
  
  /* Initialize the system 'memory' */
  for (i = 0; i < 256; ++i)
    my_memory[i] = i;
  
  if ((status = eb_socket_open(port, EB_DATAX|EB_ADDRX, &socket)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_socket_attach(socket, &handler)) != EB_OK) {
    fprintf(stderr, "Failed to attach slave device: %s\n", eb_status(status));
    return 1;
  }
  
  while (1) {
    eb_socket_block(socket, -1);
    eb_socket_poll(socket);
  }
}
