/** @file format.h
 *  @brief Functions for formatting Etherbone packet payload
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  As much as possible format/ desribes only the packet format and not logic.
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

#ifndef EB_FORMAT_H
#define EB_FORMAT_H

#include "../glue/socket.h"
#include "../glue/device.h"
#include "../transport/transport.h"

/*  sizeof(eb_max_align_t) is the maximum supported alignment. */
typedef union {
  eb_data_t data;
  eb_address_t address;
} eb_max_align_t;

EB_PRIVATE void eb_device_slave(eb_socket_t socketp, eb_transport_t transportp, eb_device_t devicep);

#endif
