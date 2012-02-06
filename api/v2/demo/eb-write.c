#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include "../etherbone.h"

/* #define BIG_CYCLE 1 */

int main(int argc, const char** argv) {
  eb_socket_t socket;
  eb_status_t status;
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
  
  if ((status = eb_socket_open(0, EB_DATAX|EB_ADDRX, &socket)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket: %s\n", eb_status(status));
    return 1;
  }
  
  if ((status = eb_device_open(socket, netaddress, EB_ADDRX|EB_DATAX, 0, &device)) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone device: %s\n", eb_status(status));
    return 1;
  }
  
  stop = 0;
  fprintf(stdout, "Writing to device %s at %08"EB_ADDR_FMT": %08"EB_DATA_FMT": ", netaddress, address, data);
  fflush(stdout);
  
  status = eb_device_write(device, address, data, 0, 0);
  fprintf(stdout, "%s\n", eb_status(status));

  eb_device_flush(device);
  
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
