/** @file posix-ip.h
 *  @brief Common methods for UDP/TCP.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Implements common IPv4/6 agnostic socket handling.
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

#ifndef EB_POSIX_IP_H
#define EB_POSIX_IP_H

#include <sys/types.h>
#include <sys/socket.h>

#include "../etherbone.h"

typedef eb_descriptor_t eb_posix_sock_t;

EB_PRIVATE void eb_posix_ip_close(eb_posix_sock_t sock);
EB_PRIVATE eb_posix_sock_t eb_posix_ip_open(int type, int port);
EB_PRIVATE socklen_t eb_posix_ip_resolve(const char* prefix, const char* address, int type, struct sockaddr_storage* out);

#endif
