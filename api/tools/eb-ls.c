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

#define _POSIX_C_SOURCE 200112L /* strtoull + getopt */

#include <unistd.h> /* getopt */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../etherbone.h"
#include "common.h"

static void help(void) {
  static char revision[20] = "$Rev::            $";
  static char date[50]     = "$Date::                                         $";
  
  *strchr(&revision[7], ' ') = 0;
  *strchr(&date[8],     ' ') = 0;
  
  fprintf(stderr, "Usage: %s [OPTION] <proto/host/port> <address/size> <value>\n", program);
  fprintf(stderr, "\n");
  fprintf(stderr, "  -a <width>     acceptable address bus widths     (8/16/32/64)\n");
  fprintf(stderr, "  -d <width>     acceptable data bus widths        (8/16/32/64)\n");
  fprintf(stderr, "  -r <retries>   number of times to attempt autonegotiation (3)\n");
  fprintf(stderr, "  -n             do not recursively explore nested buses\n");
  fprintf(stderr, "  -v             verbose operation\n");
  fprintf(stderr, "  -q             quiet: do not display warnings\n");
  fprintf(stderr, "  -h             display this help and exit\n");
  fprintf(stderr, "\n");
  fprintf(stderr, "Report Etherbone bugs to <etherbone-core@ohwr.org>\n");
  fprintf(stderr, "Version r%s (%s). Licensed under the LGPL v3.\n", &revision[7], &date[8]);
}

struct bus_record {
  int i;
  int stop;
  eb_address_t bus_begin, bus_end;
  struct bus_record* parent;
};

static void print_id(struct bus_record* br) {
  if (br->i == -1) {
    fprintf(stdout, "root");
  } else if (br->parent->i == -1) {
    fprintf(stdout, "%d", br->i + 1);
  } else {
    print_id(br->parent);
    fprintf(stdout, ".%d", br->i + 1);
  }
}

static int norecurse;
static void list_devices(eb_user_data_t user, eb_device_t dev, sdwb_t sdwb, eb_status_t status) {
  struct bus_record br;
  int devices;
  
  br.parent = (struct bus_record*)user;
  br.parent->stop = 1;
  
  if (status != EB_OK) {
    fprintf(stderr, "Failed to retrieve SDWB: %s\n", eb_status(status));
    exit(1);
  } 
  
  fprintf(stdout, "SDWB Bus "); print_id(br.parent); fprintf(stdout, "\n");
  fprintf(stdout, "  magic:           %02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x\n" 
                  "                   %02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x\n", 
                  sdwb->bus.magic[ 0], sdwb->bus.magic[ 1],
                  sdwb->bus.magic[ 2], sdwb->bus.magic[ 3],
                  sdwb->bus.magic[ 4], sdwb->bus.magic[ 5],
                  sdwb->bus.magic[ 6], sdwb->bus.magic[ 7],
                  sdwb->bus.magic[ 8], sdwb->bus.magic[ 9],
                  sdwb->bus.magic[10], sdwb->bus.magic[11],
                  sdwb->bus.magic[12], sdwb->bus.magic[13],
                  sdwb->bus.magic[14], sdwb->bus.magic[15]);
  
  fprintf(stdout, "  bus_end:         %016"PRIx64, sdwb->bus.bus_end);
  if (sdwb->bus.bus_end < br.parent->bus_begin || sdwb->bus.bus_end > br.parent->bus_end) {
    fprintf(stdout, " !!! not contained by parent bridge\n");
  } else {
    fprintf(stdout, "\n");
    br.parent->bus_end = sdwb->bus.bus_end; /* bus is smaller than bridge */
  }
  fprintf(stdout, "  sdwb_records:    %d\n",           sdwb->bus.sdwb_records);
  fprintf(stdout, "  sdwb_ver_major:  %d\n",           sdwb->bus.sdwb_ver_major);
  fprintf(stdout, "  sdwb_ver_minor:  %d\n",           sdwb->bus.sdwb_ver_minor);
  fprintf(stdout, "  bus_vendor:      %08"PRIx32"\n",  sdwb->bus.bus_vendor);
  fprintf(stdout, "  bus_device:      %08"PRIx32"\n",  sdwb->bus.bus_device);
  fprintf(stdout, "  bus_version:     %08"PRIx32"\n",  sdwb->bus.bus_version);
  fprintf(stdout, "  bus_date:        %08"PRIx32"\n",  sdwb->bus.bus_date);
  fprintf(stdout, "  bus_flags:       %08"PRIx32"\n",  sdwb->bus.bus_flags);
  fprintf(stdout, "  description:     "); fwrite(sdwb->bus.description, 1, 16, stdout); fprintf(stdout, "\n");
  fprintf(stdout, "\n");
  
  devices = sdwb->bus.sdwb_records - 1;
  for (br.i = 0; br.i < devices; ++br.i) {
    int bad, child;
    sdwb_device_t des;
    
    des = &sdwb->device[br.i];
    child = (des->wbd_flags & WBD_FLAG_HAS_CHILD) != 0;
    bad = 0;
    
    fprintf(stdout, "Device "); print_id(&br);
    
    if ((des->wbd_flags & WBD_FLAG_PRESENT) == 0) {
      fprintf(stdout, " not present\n");
      continue;
    }
    
    fprintf(stdout, "\n");
    fprintf(stdout, "  wbd_begin:       %016"PRIx64, des->wbd_begin);
    if (des->wbd_begin < br.parent->bus_begin || des->wbd_begin > br.parent->bus_end) {
      bad = 1;
      fprintf(stdout, " !!! out of range\n");
    } else {
      fprintf(stdout, "\n");
    }
    fprintf(stdout, "  wbd_end:         %016"PRIx64, des->wbd_end);
    if (des->wbd_end < br.parent->bus_begin || des->wbd_end > br.parent->bus_end) {
      bad = 1;
      fprintf(stdout, " !!! out of range\n");
    } else if (des->wbd_end < des->wbd_begin) {
      bad = 1;
      fprintf(stdout, " !!! precedes wbd_begin\n");
    } else {
      fprintf(stdout, "\n");
    }
    
    fprintf(stdout, "  sdwb_child:      %016"PRIx64, des->sdwb_child);
    if (child && (des->sdwb_child < des->wbd_begin || des->sdwb_child > des->wbd_end-64)) {
      bad = 1;
      fprintf(stdout, " !!! not contained in wbd_{begin,end}\n");
    } else {
      fprintf(stdout, "\n");
    }
    
    fprintf(stdout, "  wbd_flags:       %02"PRIx8"\n",   des->wbd_flags);
    fprintf(stdout, "  wbd_width:       %02"PRIx8"\n",   des->wbd_width);
    fprintf(stdout, "  abi_ver_major:   %d\n",           des->abi_ver_major);
    fprintf(stdout, "  abi_ver_minor:   %d\n",           des->abi_ver_minor);
    fprintf(stdout, "  abi_class:       %08"PRIx32"\n",  des->abi_class);
    fprintf(stdout, "  dev_vendor:      %08"PRIx32"\n",  des->dev_vendor);
    fprintf(stdout, "  dev_device:      %08"PRIx32"\n",  des->dev_device);
    fprintf(stdout, "  dev_version:     %08"PRIx32"\n",  des->dev_version);
    fprintf(stdout, "  dev_date:        %08"PRIx32"\n",  des->dev_date);
    fprintf(stdout, "  description:     "); fwrite(des->description, 1, 16, stdout); fprintf(stdout, "\n");
    fprintf(stdout, "\n");
    
    if (!norecurse && child && !bad) {
      br.bus_begin = des->wbd_begin;
      br.bus_end = des->wbd_end;
      eb_sdwb_scan_bus(dev, des, &br, &list_devices);
      
      while (!br.stop) {
        eb_socket_block(eb_device_socket(dev), -1);
        eb_socket_poll(eb_device_socket(dev));
      }
    }
  }
}

int main(int argc, char** argv) {
  long value;
  char* value_end;
  int opt, error;
  
  struct bus_record br;
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  
  /* Specific command-line options */
  const char* netaddress;
  int attempts;
  
  br.parent = 0;
  br.i = -1;
  br.stop = 0;
  br.bus_begin = 0;
  br.bus_end = ~(eb_address_t)0;
  
  /* Default command-line arguments */
  program = argv[0];
  address_width = EB_ADDRX;
  data_width = EB_DATAX;
  attempts = 3;
  quiet = 0;
  verbose = 0;
  norecurse = 0;
  error = 0;
  
  /* Process the command-line arguments */
  while ((opt = getopt(argc, argv, "a:d:r:nvqh")) != -1) {
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
    case 'r':
      value = strtol(optarg, &value_end, 0);
      if (*value_end || value < 0 || value > 100) {
        fprintf(stderr, "%s: invalid number of retries -- '%s'\n", program, optarg);
        return 1;
      }
      attempts = value;
      break;
    case 'n':
      norecurse = 1;
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
  
  if (optind + 1 != argc) {
    fprintf(stderr, "%s: expecting non-optional argument: <protocol/host/port>\n", program);
    return 1;
  }
  
  netaddress = argv[optind];
  
  if ((status = eb_socket_open(EB_ABI_CODE, 0, address_width|data_width, &socket)) != EB_OK) {
    fprintf(stderr, "%s: failed to open Etherbone socket: %s\n", program, eb_status(status));
    return 1;
  }
  
  if ((status = eb_device_open(socket, netaddress, EB_ADDRX|EB_DATAX, attempts, &device)) != EB_OK) {
    fprintf(stderr, "%s: failed to open Etherbone device: %s\n", program, eb_status(status));
    return 1;
  }
  
  /* Find the limit of the bus space based on the address width */
  br.bus_end >>= (sizeof(eb_address_t) - (eb_device_width(device) >> 4))*8;
  
  if ((status = eb_sdwb_scan_root(device, &br, &list_devices)) != EB_OK) {
    fprintf(stderr, "%s: failed to scan remote device: %s\n", program, eb_status(status));
    return 1;
  }
  
  while (!br.stop) {
    eb_socket_block(socket, -1);
    eb_socket_poll(socket);
  }
  
  if ((status = eb_device_close(device)) != EB_OK) {
    fprintf(stderr, "%s: failed to close Etherbone device: %s\n", program, eb_status(status));
    return 1;
  }
  
  if ((status = eb_socket_close(socket)) != EB_OK) {
    fprintf(stderr, "%s: failed to close Etherbone socket: %s\n", program, eb_status(status));
    return 1;
  }
  
  return 0;
}
