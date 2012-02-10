#include <stdio.h>
#include <stdlib.h>
#include "etherbone.h"

static eb_socket_t socket;
static eb_device_t fpga;
static eb_data_t x;

extern void button(eb_user_data_t user, eb_status_t ok, eb_data_t button);
extern void blink_done(eb_user_data_t data, eb_status_t ok);
extern void complete(eb_user_data_t data, eb_status_t status, int completed);

void setup_gui() {
  if (eb_device_open(socket, "192.168.3.1:9191", &fpga) != EB_OK) {
    fprintf(stderr, "Couldn't open remote FPGA!\n");
    exit(1);
  }
  
  // Setup GUI window/etc
}

void quit_gui() {
  eb_device_close(fpga);
}

void clicked() {
  // Toggle an LED
  eb_device_write(fpga, 0x16, 1, 0, &blink_done);
   
  // Read the status of the push button to a member function
  // We use 'proxy' to fix convert the member function to a static function
  eb_device_read(fpga, 0x20, 0, &button);
}

void button(eb_user_data_t user, eb_status_t ok, eb_data_t button) {
  if (ok != EB_OK) {
    fprintf(stderr, "Couldn't read the button!");
    exit(1);
  }
  
  if (button) { // If the FPGA button is pushed
    // Do an atomic 4 byte read and 8 byte write cycle
    eb_cycle_t cycle = eb_cycle_open(fpga, 0, &complete);
    eb_cycle_read(cycle, 0x32, &x);
    eb_cycle_write(cycle, 0x32, 6);
    eb_cycle_write(cycle, 0x36, 7);
    eb_cycle_close(cycle);
    
    // Here's how to do it if you need a loop or something
    cycle = eb_cycle_open(fpga, 0, 0); // no ack
    for (int i = 0; i < 10; ++i)
      eb_cycle_write(cycle, i*4, 0x42);
    eb_cycle_close(cycle);
    // end of cycle
    
    // We have two queued cycles, flush them both out
    eb_device_flush(fpga);
  }
}
    
void blink_done(eb_user_data_t data, eb_status_t ok) {
}

void complete(eb_user_data_t data, eb_status_t status, int completed) {
  switch (status) {
  case EB_OK:
    fprintf(stderr, "Read back: %d\n", x);
    break;
  
  case EB_FAIL:
  case EB_ABORT:
  case EB_OVERFLOW:
    fprintf(stderr, "The %dth phase of the cycle failed!\n", completed);
    break;
  }
}
  
int main() { 
  if (eb_socket_open(0, &socket) != EB_OK) {
      fprintf(stderr, "Couldn't open Etherbone socket\n");
      exit(1);
  }
  
  // Startup the GUI
  setup_gui();
  
  // Hook the socket into the GUI's main loop
  // GUI.watch(eb_socket_descriptor(socket), socket, eb_socket_poll);
  
  // (pretend to) Run the GUI's main loop
  clicked();
  while (1) eb_socket_poll(socket);
  
  quit_gui();
  eb_socket_close(socket);
  return 0;
}
