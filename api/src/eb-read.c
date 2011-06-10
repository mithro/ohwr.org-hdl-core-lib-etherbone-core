#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include "../etherbone.h"

static void set_stop(eb_user_data_t user, eb_status_t status, eb_data_t data) {
  int* x = (int*)user;
  *x = 1;
  fprintf(stdout, "%016"PRIx64".\n", data);
}

int main(int argc, const char** argv) {
  eb_socket_t socket;
  eb_device_t device;
  eb_network_address_t netaddress;
  eb_address_t address;
  int timeout;
  int stop;
  
  if (argc != 3) {
    fprintf(stderr, "Syntax: %s <remote-ip-port> <address>\n", argv[0]);
    return 1;
  }
  
  netaddress = argv[1];
  address = strtol(argv[2], 0, 0);
  
  if (eb_socket_open(0, 0, &socket) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket\n");
    return 1;
  }
  
  if (eb_device_open(socket, netaddress, EB_ADDRX, EB_DATA16, &device) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone device\n");
    return 1;
  }
  
  stop = 0;
  fprintf(stdout, "Reading from device %s at %08"PRIx64": ", netaddress, address);
  fflush(stdout);
  
  eb_device_read(device, address, &stop, &set_stop);
  eb_device_flush(device);
  
  timeout = 5000000; /* 5 seconds */
  while (!stop && timeout > 0) {
    timeout -= eb_socket_block(socket, timeout);
    eb_socket_poll(socket);
  }
  if (!stop) {
    fprintf(stdout, "FAILURE!\n");
    fprintf(stderr, "Read from %s/%08"PRIx64" timed out.\n", netaddress, address);
  }
  
  if (eb_device_close(device) != EB_OK) {
    fprintf(stderr, "Failed to close Etherbone device\n");
    return 1;
  }
  
  if (eb_socket_close(socket) != EB_OK) {
    fprintf(stderr, "Failed to close Etherbone socket\n");
    return 1;
  }
  
  return 0;
}
