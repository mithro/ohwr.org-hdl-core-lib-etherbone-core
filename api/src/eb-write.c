#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include "../etherbone.h"

int main(int argc, const char** argv) {
  eb_socket_t socket;
  eb_device_t device;
  eb_network_address_t netaddress;
  eb_address_t address;
  eb_data_t data;
  int stop;
  
  if (argc != 4) {
    fprintf(stderr, "Syntax: %s <remote-ip-port> <address> <data>\n", argv[0]);
    return 1;
  }
  
  netaddress = argv[1];
  address = strtol(argv[2], 0, 0);
  data = strtol(argv[3], 0, 0);
  
  if (eb_socket_open(0, 0, &socket) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket\n");
    return 1;
  }
  
  if (eb_device_open(socket, netaddress, EB_DATAX, &device) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone device\n");
    return 1;
  }
  
  stop = 0;
  fprintf(stdout, "Writing to device %s at %08"PRIx64": %08"PRIx64"\n", netaddress, address, data);
  fflush(stdout);
  
  eb_device_write(device, address, data);
  eb_device_flush(device);
  
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
