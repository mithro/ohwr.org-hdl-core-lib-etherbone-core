/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone device data structure.
 */

#define ETHERBONE_IMPL

#include "widths.h"

int eb_width_possible(eb_width_t width) {
  eb_width_t data = width & 0xf;
  eb_width_t addr = width >> 4;
  return data != 0 && addr != 0;
}

int eb_width_refined(eb_width_t width) {
  eb_width_t data = width & 0xf;
  eb_width_t addr = width >> 4;
  
  return data != 0 && addr != 0 && 
         (data & (data-1)) == 0 && 
         (addr & (addr-1)) == 0;
}

eb_width_t eb_width_refine(eb_width_t width) {
  eb_width_t data = width & 0xf;
  eb_width_t addr = width >> 4;
  
  addr |= addr >> 1;
  addr |= addr >> 2;
  ++addr;
  addr >>= 1;
  
  data |= data >> 1;
  data |= data >> 2;
  ++data;
  data >>= 1;
  
  return (addr << 4) | data;
}
