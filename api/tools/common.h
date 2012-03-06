/** @file common.h
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

#ifndef COMMON_H
#define COMMON_H

extern const char* endian_str[4];
extern const char* width_str[16];

int parse_width(char* str);

/* data should be a eb_format_t */
void find_device(eb_user_data_t data, eb_device_t dev, sdwb_t sdwb, eb_status_t status);

/* must be filled in by the main program: */
extern const char* program;
extern eb_width_t address_width, data_width;
extern eb_address_t address;
extern eb_format_t endian;
extern int verbose, quiet;

#endif
