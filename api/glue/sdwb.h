/** @file sdwb.c
 *  @brief Implement the SDWB data structure on the local bus.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  We reserved the low 8K memory region for this device.
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

#ifndef SDWB_H
#define SDWB_H

#include "../etherbone.h"

typedef EB_POINTER(eb_sdwb_scan) eb_sdwb_scan_t;
struct eb_sdwb_scan {
  eb_user_data_t user_data;
  sdwb_callback_t cb;
  eb_address_t bus_base;
};

#endif
