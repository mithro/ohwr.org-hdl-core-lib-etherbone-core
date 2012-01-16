#include <stdio.h>
#include <stdlib.h>
#include "../etherbone.h"

struct stop {
  int done;
  eb_data_t result;
};
static void set_stop(eb_user_data_t user, eb_status_t status) {
  struct stop* stop = (struct stop*)user;
  stop->done = 1;
  if (status != EB_OK) {
    fprintf(stdout, "%s\n", eb_status(status));
  } else {
    fprintf(stdout, "%016"EB_DATA_FMT".\n", stop->result);
  }
}

int main(int argc, const char** argv) {
  eb_socket_t socket;
  eb_status_t status;
  eb_device_t device;
  eb_network_address_t netaddress;
  eb_address_t address;
  struct stop stop;
  int timeout;
  
  if (argc != 3) {
    fprintf(stderr, "Syntax: %s <remote-ip-port> <address>\n", argv[0]);
    return 1;
  }
  
  netaddress = argv[1];
  address = strtol(argv[2], 0, 0);
  
  if ((status = eb_socket_open(0, EB_DATAX|EB_ADDRX, &socket)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_device_open(socket, netaddress, EB_ADDR32|EB_DATA16, 0, &device)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone device: %s\n", eb_status(status));
    return 1;
  }
  
  stop.result = 0;
  fprintf(stdout, "Reading from device %s at %08"EB_ADDR_FMT": ", netaddress, address);
  fflush(stdout);
  
  eb_device_read(device, address, &stop.result, &stop, &set_stop);
  eb_device_flush(device);
  
  timeout = 5000000; /* 5 seconds */
  while (!stop.done && timeout > 0) {
    timeout -= eb_socket_block(socket, timeout);
    eb_socket_poll(socket);
  }
  if (!stop.done) {
    fprintf(stdout, "FAILURE!\n");
    fprintf(stderr, "Read from %s/%08"EB_ADDR_FMT" timed out.\n", netaddress, address);
  }
  
  if ((status = eb_device_close(device)) != EB_OK) {
    fprintf(stderr, "Failed to close Etherbone device: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_socket_close(socket)) != EB_OK) {
    fprintf(stderr, "Failed to close Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  return 0;
}