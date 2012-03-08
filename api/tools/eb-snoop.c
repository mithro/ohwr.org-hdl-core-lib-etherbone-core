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

#define _POSIX_C_SOURCE 200112L /* strtoull + getopt */

#include <unistd.h> /* getopt */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../etherbone.h"
#include "common.h"

static uint8_t* my_memory;

static void help(void) {
  static char revision[20] = "$Rev::            $";
  static char date[50]     = "$Date::                                         $";
  
  *strchr(&revision[7], ' ') = 0;
  *strchr(&date[8],     ' ') = 0;
  
  fprintf(stderr, "Usage: %s [OPTION] <port> <address-range>\n", program);
  fprintf(stderr, "\n");
  fprintf(stderr, "  -a <width>     acceptable address bus widths     (8/16/32/64)\n");
  fprintf(stderr, "  -d <width>     acceptable data bus widths        (8/16/32/64)\n");
  fprintf(stderr, "  -w <width>     SDWB device operation widths      (8/16/32/64)\n");
  fprintf(stderr, "  -b             big-endian operation                    (auto)\n");
  fprintf(stderr, "  -l             little-endian operation                 (auto)\n");
  fprintf(stderr, "  -v             verbose operation\n");
  fprintf(stderr, "  -q             quiet: do not display warnings\n");
  fprintf(stderr, "  -h             display this help and exit\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Report Etherbone bugs to <etherbone-core@ohwr.org>\n");
  fprintf(stderr, "Version r%s (%s). Licensed under the LGPL v3.\n", &revision[7], &date[8]);
}

static eb_status_t my_read(eb_user_data_t user, eb_address_t req_address, eb_width_t width, eb_data_t* data) {
  int i;
  eb_data_t out;
  
  if (verbose)
    fprintf(stdout, "Received read to address 0x%"EB_ADDR_FMT" of %d bits: ", req_address, (width&EB_DATAX)*8);
  
  out = 0;
  width &= EB_DATAX;
  req_address -= address;
  
  if (endian == EB_BIG_ENDIAN) {
    for (i = 0; i < width; ++i) {
      out <<= 8;
      out |= my_memory[req_address+i];
    }
  } else { /* little endian */
    for (i = width-1; i >= 0; --i) {
      out <<= 8;
      out |= my_memory[req_address+i];
    }
  }
  
  if (verbose)
    fprintf(stdout, "0x%"EB_ADDR_FMT"\n", out);
  
  *data = out;
  return EB_OK;
}

static eb_status_t my_write(eb_user_data_t user, eb_address_t req_address, eb_width_t width, eb_data_t data) {
  int i;
  
  if (verbose)
    fprintf(stdout, "Received write to address 0x%"EB_ADDR_FMT" of %d bits: 0x%"EB_DATA_FMT"\n", req_address, (width&EB_DATAX)*8, data);
  
  width &= EB_DATAX;
  req_address -= address;
  
  if (endian == EB_BIG_ENDIAN) {
    for (i = width-1; i >= 0; --i) {
      my_memory[req_address+i] = data & 0xff;
      data >>= 8;
    }
  } else { /* little endian */
    for (i = 0; i < width; ++i) {
      my_memory[req_address+i] = data & 0xff;
      data >>= 8;
    }
  }
  
  return EB_OK;
}

int main(int argc, char** argv) {
  long value;
  char* value_end;
  int opt, error;
  
  struct sdwb_device device;
  struct eb_handler handler;
  eb_status_t status;
  eb_socket_t socket;
  
  /* Specific command-line arguments */
  eb_format_t width;
  const char* port;
  
  /* Default arguments */
  program = argv[0];
  address_width = EB_ADDRX;
  data_width = EB_DATAX;
  width = EB_DATAX;
  endian = EB_BIG_ENDIAN;
  verbose = 0;
  quiet = 0;
  error = 0;
  
  /* Process the command-line arguments */
  while ((opt = getopt(argc, argv, "a:d:w:blvqh")) != -1) {
    switch (opt) {
    case 'a':
      value = parse_width(optarg);
      if (value < 0) {
        fprintf(stderr, "%s: invalid address width -- '%s'\n", program, optarg);
        return 1;
      }
      address_width = value << 4;
      break;
    case 'd':
      value = parse_width(optarg);
      if (value < 0) {
        fprintf(stderr, "%s: invalid data width -- '%s'\n", program, optarg);
        return 1;
      }
      data_width = value;
      break;
    case 'w':
      value = parse_width(optarg);
      if (value < 0) {
        fprintf(stderr, "%s: invalid SDWB width -- '%s'\n", program, optarg);
        return 1;
      }
      width = value;
      break;
    case 'b':
      endian = EB_BIG_ENDIAN;
      break;
    case 'l':
      endian = EB_LITTLE_ENDIAN;
      break;
    case 'v':
      verbose = 1;
      break;
    case 'q':
      quiet = 1;
      break;
    case 'h':
      help();
      return 1;
    case ':':
    case '?':
      error = 1;
      break;
    default:
      fprintf(stderr, "%s: bad getopt result\n", program);
      return 1;
    }
  }
  
  if (error) return 1;
  
  if (optind + 2 != argc) {
    fprintf(stderr, "%s: expecting two non-optional arguments: <port> <address-range>\n", program);
    return 1;
  }
  
  port = argv[optind];
  
  address = device.wbd_begin = strtoull(argv[optind+1], &value_end, 0);
  if (*value_end != '-') {
    fprintf(stderr, "%s: wrong address-range format <begin>-<end> -- '%s'\n", 
                    program, argv[optind+1]);
    return 1;
  }
  
  device.wbd_end = strtoull(value_end+1, &value_end, 0);
  if (*value_end != 0) {
    fprintf(stderr, "%s: wrong address-range format <begin>-<end> -- '%s'\n", 
                    program, argv[optind+1]);
    return 1;
  }
  
  device.sdwb_child = 0;
  device.wbd_flags = WBD_FLAG_PRESENT | ((endian == EB_LITTLE_ENDIAN)?WBD_FLAG_LITTLE_ENDIAN:0);
  device.wbd_width = width;
  device.abi_ver_major = 1;
  device.abi_ver_minor = 0;
  device.abi_class = 0x1;
  device.dev_vendor = 0x651; /* GSI */
  device.dev_device = 0x2;
  device.dev_version = 1;
  device.dev_date = 0x20120228;
  memcpy(device.description, "Software-Memory ", 16);
  
  handler.device = &device;
  handler.data = 0;
  handler.read = &my_read;
  handler.write = &my_write;
  
  if ((my_memory = calloc((device.wbd_end-device.wbd_begin)+1, 1)) == 0) {
    fprintf(stderr, "%s: insufficient memory for 0x%"EB_ADDR_FMT"-0x%"EB_ADDR_FMT"\n",
                    program, (eb_address_t)device.wbd_begin, (eb_address_t)device.wbd_end);
    return 1;
  }
  
  if ((status = eb_socket_open(EB_ABI_CODE, port, address_width|data_width, &socket)) != EB_OK) {
    fprintf(stderr, "%s: failed to open Etherbone socket: %s\n", program, eb_status(status));
    return 1;
  }
  
  if ((status = eb_socket_attach(socket, &handler)) != EB_OK) {
    fprintf(stderr, "%s: failed to attach slave device: %s\n", program, eb_status(status));
    return 1;
  }
  
  while (1) {
    eb_socket_run(socket, -1);
  }
  
  return 0;
}
