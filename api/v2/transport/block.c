/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements blocking wait using select.
 */

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
  
  if (fd > set->nfd) set->nfd = fd;
  FD_SET(fd, &set->rfds);
}

int eb_socket_block(eb_socket_t socketp, int timeout_us) {
  struct eb_block_readset readset;
  struct timeval timeout, start, stop;
  time_t eb_deadline;
  int eb_timeout_us;
  
  gettimeofday(&start, 0);
  
  FD_ZERO(&readset.rfds);
  readset.nfd = 0;
  
  /* Find all descriptors and current timestamp */
  eb_socket_descriptor(socketp, &readset, &eb_update_readset);
  eb_deadline = eb_socket_timeout(socketp, start.tv_sec);
  
  eb_timeout_us = (eb_deadline - start.tv_sec)*1000000;
  if (timeout_us == -1 || timeout_us > eb_timeout_us)
    timeout_us = eb_timeout_us;
  
  timeout.tv_sec  = timeout_us / 1000000;
  timeout.tv_usec = timeout_us % 1000000;
  
  select(readset.nfd+1, &readset.rfds, 0, 0, &timeout);
  gettimeofday(&stop, 0);
  
  return (stop.tv_sec - start.tv_sec)*1000000 + (stop.tv_usec - start.tv_usec);
}