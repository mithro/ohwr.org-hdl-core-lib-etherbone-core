/** @file block.c
 *  @brief A mostly-portable implementation of eb_socket_block.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Implement eb_socket_block using select().
 *  This should work on any POSIX operating system.
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

#define ETHERBONE_IMPL

#include "transport.h"
#include "../glue/socket.h"
#include "../glue/device.h"
#include "../memory/memory.h"

#include <sys/types.h>
#include <sys/time.h>
#include <sys/select.h>
#include <unistd.h>

struct eb_block_readset {
  int nfd;
  fd_set rfds;
};

static void eb_update_readset(eb_user_data_t data, eb_descriptor_t fd) {
  struct eb_block_readset* set = (struct eb_block_readset*)data;
  
  if (fd != -1) {
    if (fd > set->nfd) set->nfd = fd;
    FD_SET(fd, &set->rfds);
  }
}

int eb_socket_block(eb_socket_t socketp, int timeout_us) {
  struct eb_block_readset readset;
  struct timeval timeout, start, stop;
  time_t eb_deadline;
  int eb_timeout_us;
  
  /* Find all descriptors and current timestamp */
  FD_ZERO(&readset.rfds);
  readset.nfd = 0;
  eb_socket_descriptor(socketp, &readset, &eb_update_readset);
  
  /* Determine the deadline */
  gettimeofday(&start, 0);
  eb_socket_settime(socketp, start.tv_sec);
  eb_deadline = eb_socket_timeout(socketp);
  
  eb_timeout_us = (eb_deadline - start.tv_sec)*1000000;
  if (timeout_us == -1 || timeout_us > eb_timeout_us)
    timeout_us = eb_timeout_us;
    
  if (timeout_us < 0) timeout_us = 0;
  
  timeout.tv_sec  = timeout_us / 1000000;
  timeout.tv_usec = timeout_us % 1000000;
  
  select(readset.nfd+1, &readset.rfds, 0, 0, &timeout);
  gettimeofday(&stop, 0);
  
  /* Update the timestamp cache */
  eb_socket_settime(socketp, stop.tv_sec);
  
  return (stop.tv_sec - start.tv_sec)*1000000 + (stop.tv_usec - start.tv_usec);
}
