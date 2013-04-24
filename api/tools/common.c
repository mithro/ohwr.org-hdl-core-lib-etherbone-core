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

eb_address_t end_of_device;
void find_device(eb_user_data_t data, eb_device_t dev, const struct sdb_table* sdb, eb_status_t status) {
  int i, devices;
  eb_format_t size, dev_endian;
  eb_format_t* device_support;
  const union sdb_record* des;
  
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
        des->bridge.sdb_component.addr_first <= address && address <= des->bridge.sdb_component.addr_last) {
      
      if (verbose) {
        fprintf(stdout, "  discovered bridge (");
        fwrite(des->bridge.sdb_component.product.name, 1, sizeof(des->bridge.sdb_component.product.name), stdout);
        fprintf(stdout, ") at 0x%"EB_ADDR_FMT" -- exploring...\n", (eb_address_t)des->bridge.sdb_component.addr_first);
      }
      
      eb_sdb_scan_bus(dev, &des->bridge, data, &find_device);
      return;
    }
    
    if (des->empty.record_type == sdb_device && 
        des->device.sdb_component.addr_first <= address && address <= des->device.sdb_component.addr_last) {
      
      
      if ((des->device.bus_specific & SDB_WISHBONE_LITTLE_ENDIAN) != 0)
        dev_endian = EB_LITTLE_ENDIAN;
      else
        dev_endian = EB_BIG_ENDIAN;
      
      size = des->device.bus_specific & EB_DATAX;
      
      if (verbose) {
        fprintf(stdout, "  discovered device (");
        fwrite(des->device.sdb_component.product.name, 1, sizeof(des->device.sdb_component.product.name), stdout);
        fprintf(stdout, ") at 0x%"EB_ADDR_FMT" with %s-bit %s\n",
                        (eb_address_t)des->device.sdb_component.addr_first, eb_width_data(size), eb_format_endian(dev_endian));
      }
      
      *device_support = dev_endian | size;
      end_of_device = des->device.sdb_component.addr_last;
      return;
    }
  }
  
  if (!quiet)
    fprintf(stderr, "%s: warning: could not locate Wishbone device at address 0x%"EB_ADDR_FMT"\n", 
                    program, address);
  *device_support = endian | EB_DATAX;
}
