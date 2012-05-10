/** @file common.c
 *  @brief Common helper functions for eb-command-line
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  These methods are command-line specific.
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

#include "../etherbone.h"
#include "common.h"

#include <stdio.h>
#include <stdlib.h>

const char* program;
eb_width_t address_width, data_width;
eb_address_t address;
eb_format_t endian;
int verbose, quiet;

const char* endian_str[4] = {
 /*  0 */ "auto-endian",
 /*  1 */ "big-endian",
 /*  2 */ "little-endian",
 /*  3 */ "invalid-endian"
};

const char* width_str[16] = {
 /*  0 */ "<null>",
 /*  1 */ "8",
 /*  2 */ "16",
 /*  3 */ "8/16",
 /*  4 */ "32",
 /*  5 */ "8/32",
 /*  6 */ "16/32",
 /*  7 */ "8/16/32",
 /*  8 */ "64",
 /*  9 */ "8/64",
 /* 10 */ "16/64",
 /* 11 */ "8/16/64",
 /* 12 */ "32/64",
 /* 13 */ "8/32/64",
 /* 14 */ "16/32/64",
 /* 15 */ "8/16/32/64"
};

int parse_width(char* str) {
  int width, widths;
  char* next;
  
  widths = 0;
  while (1) {
    width = strtol(str, &next, 0);
    if (width != 8 && width != 16 && width != 32 && width != 64) break;
    widths |= width/8;
    if (!*next) return widths;
    if (*next != '/' && *next != ',') break;
    str = next+1;
  }
  
  return -1;
}

void find_device(eb_user_data_t data, eb_device_t dev, sdb_t sdb, eb_status_t status) {
  int i, devices;
  eb_format_t size, dev_endian;
  eb_format_t* device_support;
  sdb_record_t des;
  
  device_support = (eb_format_t*)data;
  
  if (status != EB_OK) {
    fprintf(stderr, "%s: failed to retrieve SDB data: %s\n", program, eb_status(status));
    exit(1);
  }
  
  des = 0; /* silence warning */
  devices = sdb->interconnect.sdb_records - 1;
  for (i = 0; i < devices; ++i) {
    des = &sdb->record[i];
    
    if (des->empty.record_type == sdb_bridge && 
        des->bridge.component.begin <= address && address <= des->bridge.component.end) {
      
      if (verbose) {
        fprintf(stdout, "  discovered bridge (");
        fwrite(des->bridge.component.product.name, 1, sizeof(des->bridge.component.product.name), stdout);
        fprintf(stdout, ") at 0x%"EB_ADDR_FMT" -- exploring...\n", (eb_address_t)des->bridge.component.begin);
      }
      
      eb_sdb_scan_bus(dev, &des->bridge, data, &find_device);
      return;
    }
    
    if (des->empty.record_type == sdb_device && 
        des->device.component.begin <= address && address <= des->device.component.end) {
      
      
      if ((des->device.bus_specific & SDB_WISHBONE_LITTLE_ENDIAN) != 0)
        dev_endian = EB_LITTLE_ENDIAN;
      else
        dev_endian = EB_BIG_ENDIAN;
      
      size = des->device.bus_specific & EB_DATAX;
      
      if (verbose) {
        fprintf(stdout, "  discovered (");
        fwrite(des->device.component.product.name, 1, sizeof(des->device.component.product.name), stdout);
        fprintf(stdout, ") at 0x%"EB_ADDR_FMT" with %s-bit %s\n",
                        (eb_address_t)des->device.component.begin, width_str[size], endian_str[dev_endian >> 4]);
      }
      
      *device_support = dev_endian | size;
      return;
    }
  }
  
  if (!quiet)
    fprintf(stderr, "%s: warning: could not locate Wishbone device at address 0x%"EB_ADDR_FMT"\n", 
                    program, address);
  *device_support = endian | EB_DATAX;
}
