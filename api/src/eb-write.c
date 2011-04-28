#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include "../etherbone.h"

/* #define BIG_CYCLE 1 */

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
  

#ifdef BIG_CYCLE
  if (1) {
    eb_cycle_t cycle = eb_cycle_open_read_write(device, 0, 0, address, EB_LINEAR);
    eb_cycle_write(cycle, 0x12);
    eb_cycle_write(cycle, 0x13);
    eb_cycle_close(cycle);
  }
  
  if (1) {
    eb_cycle_t cycle = eb_cycle_open_read_write(device, 0, 0, address, EB_FIFO);
    eb_cycle_write(cycle, 0x14);
    eb_cycle_write(cycle, 0x15);
    eb_cycle_close(cycle);
  }
#endif
  
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
