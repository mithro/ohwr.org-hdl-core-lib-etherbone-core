/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements UDP on posix sockets.
 */

#define ETHERBONE_IMPL

#include "transport.h"
#include "posix-ip.h"
#include "ssh.h"

#include <sys/socket.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

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
  int socks[2];
  int len;
  
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
  
  if (linkp == 0) return -1;
  
  link = (struct eb_ssh_link*)linkp;
  return recv(link->socket, buf, len, MSG_DONTWAIT);
}

int eb_ssh_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_ssh_link* link;
  
  if (linkp == 0) return -1;
  
  link = (struct eb_ssh_link*)linkp;
  return recv(link->socket, buf, len, 0);
}

void eb_ssh_send(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {
  struct eb_ssh_link* link;
  
  link = (struct eb_ssh_link*)linkp;
  send(link->socket, buf, len, 0);
}
