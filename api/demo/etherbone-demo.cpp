#include <iostream>
#include <cstdlib>
#include "etherbone.h"

using namespace etherbone;

class MyApp {
  private:
    Device fpga;
    data_t x;
  
  public:
    MyApp(Socket& sock) {
      if (fpga.open(sock, "192.168.3.1:9191") != EB_OK) {
        std::cerr << "Couldn't open remote FPGA" << std::endl;
        exit(1);
      }
      
      // Setup GUI window/etc
    }
    
    ~MyApp() {
      fpga.close();
    }
    
    void clicked() {
      // Toggle an LED
      fpga.write(0x16, 1, this, &blink_done);
      
      // Read the status of the push button to a member function
      // We use 'proxy' to fix convert the member function to a static function
      fpga.read(0x20, this, proxy<MyApp,&MyApp::button>);
    }
    
    void button(status_t ok, data_t button) {
      if (ok != EB_OK) {
        std::cerr << "Couldn't read the button!" << std::endl;
        exit(1);
      }
      
      if (button) { // If the FPGA button is pushed
        // Do an atomic 4 byte read and 8 byte write cycle
        Cycle(fpga, this, proxy<MyApp,&MyApp::complete>)
          .read(0x32, &x)
          .write(0x32, 6)
          .write(0x36, 7);
        
        // Here's how to do it if you need a loop or something
        {
          Cycle cycle(fpga); // no ack
          for (int i = 0; i < 10; ++i)
            cycle.write(i*4, 0x42);
        } // end of cycle
        
        // We have two queued cycles, flush them both out
        fpga.flush();
      }
    }
    
    static void blink_done(MyApp* obj, status_t ok) {
      // An example of a static member callback
    }
    
    void complete(status_t status, int completed) {
      switch (status) {
      case EB_OK:
        std::cout << "Read back: " << x << std::endl;
        break;
      
      case EB_FAIL:
      case EB_ABORT:
      case EB_OVERFLOW:
        std::cerr << "The " << completed << "th phase of the cycle failed!" << std::endl;
        break;
      }
    }
};
  
int main() { 
  Socket socket;
  if (socket.open() != EB_OK) {
      std::cerr << "Couldn't open Etherbone socket" << std::endl;
      exit(1);
  }
  
  {
    // Create the GUI
    MyApp myApp(socket);
  
    // Hook the socket into the GUI's main loop
    // GUI.watch(socket.descriptor(), &socket, &Socket::poll);
    
    // (pretend to) Run the GUI's main loop
    myApp.clicked();
    while (1) socket.poll();
  } // GUI destructor is running, closing fpga
  
  socket.close();
  return 0;
}
