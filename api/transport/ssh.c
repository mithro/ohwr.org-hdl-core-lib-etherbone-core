/** @file ssh.c
 *  @brief This implements an SSH binding using popen().
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Etherbone over ssh is implemented using a helper process.
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
#include "posix-ip.h"
#include "ssh.h"

#include <string.h>
#include <stdlib.h>
#include <errno.h>

eb_status_t eb_ssh_open(struct eb_transport* transportp, int port) {
  /* noop */
  return EB_OK;
}

void eb_ssh_close(struct eb_transport* transportp) {
  /* noop */
}

eb_status_t eb_ssh_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address) {
  struct eb_ssh_link* link;
  const char* slash;
  const char* command;
  char host[250];
  int len;
#ifndef __WIN32
  int socks[2];
#endif
  
  link = (struct eb_ssh_link*)linkp;
  
  if (strncmp(address, "ssh/", 4)) 
    return EB_ADDRESS;
  address += 4;
  if (strlen(address) >= sizeof(host)-1)
    return EB_ADDRESS;
    
  slash = strchr(address, '/');
  if (slash == 0) {
    strcpy(host, address);
    command = "eb_proxy";
  } else {
    len = slash - address;
    strncpy(host, address, len);
    host[len] = 0;
    command = slash+1;
  }

#ifdef __WIN32
  return EB_FAIL;
#else  
  if (socketpair(PF_UNIX, SOCK_STREAM, 0, socks) < 0) 
    return EB_FAIL;
  
  if (fork() == 0) {
    dup2(socks[1], 0);
    dup2(socks[1], 1);
    eb_posix_ip_close(socks[0]);
    eb_posix_ip_close(socks[1]);
    execlp("ssh", "ssh", host, command, NULL);
    exit(-1);
  }
  
  link->socket = socks[0];
  eb_posix_ip_close(socks[1]);
  return EB_OK;
#endif
}

void eb_ssh_disconnect(struct eb_transport* transportp, struct eb_link* linkp) {
  struct eb_ssh_link* link;
  
  link = (struct eb_ssh_link*)linkp;
  eb_posix_ip_close(link->socket);
}

eb_descriptor_t eb_ssh_fdes(struct eb_transport* transportp, struct eb_link* linkp) {
  struct eb_ssh_link* link;
  
  if (linkp == 0) return -1;
  
  link = (struct eb_ssh_link*)linkp;
  return link->socket;
}

int eb_ssh_poll(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_ssh_link* link;
  int result;
  
  if (linkp == 0) return 0;
  
  link = (struct eb_ssh_link*)linkp;
  result = recv(link->socket, (char*)buf, len, MSG_DONTWAIT);
  
  if (result == -1 && errno == EAGAIN) return 0;
  if (result == 0) return -1;
  return result;
}

int eb_ssh_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_ssh_link* link;
  int result;
  
  if (linkp == 0) return 0;
  
  link = (struct eb_ssh_link*)linkp;
  result = recv(link->socket, (char*)buf, len, 0);
  
  /* EAGAIN impossible on blocking read */
  if (result == 0) return -1;
  return result;
}

void eb_ssh_send(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_ssh_link* link;
  
  /* linkp == 0 impossible if poll returns 0 on 0 */
  link = (struct eb_ssh_link*)linkp;
  send(link->socket, (const char*)buf, len, 0);
}
