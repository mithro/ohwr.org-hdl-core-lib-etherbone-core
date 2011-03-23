#include "../etherbone.h"
#include "udp.h"

#include <vector>
#include <assert.h>
#include <errno.h>

struct eb_cycle {
  eb_device_t			device;
  eb_cycle_callback_t		callback;
  eb_user_data_t		user_data;
  
  eb_address_t			write_base;
  eb_mode_t			write_mode;
  
  std::vector<eb_address_t>	reads;
  std::vector<eb_data_t>	writes;
};

struct eb_device {
  udp_address_t			address;
  eb_socket_t			socket;
  std::vector<eb_cycle_t>	queue;
  unsigned int			queue_size;
  unsigned int			cycles;
  unsigned int			outstanding;
  unsigned int			completed;
  /* auto probed: */
  unsigned int			segment_words;
  unsigned int			portSz;
  unsigned int			addrSz;
};

struct eb_socket {
  udp_socket_t			socket;
  unsigned int			devices;
};

eb_status_t eb_socket_open(int port, eb_socket_t* result) {
  udp_socket_t sock;
  
  if (udp_socket_open(port, &sock) != -1) {
    eb_socket_t out = new eb_socket;
    out->socket = sock;
    out->devices = 0;
    *result = out;
    return EB_OK;
  } else {
    *result = 0;
    if (errno == EADDRINUSE)
      return EB_BUSY;
    else
      return EB_FAIL;
  }
}

eb_status_t eb_socket_close(eb_socket_t socket) {
  if (socket->devices > 0)
    return EB_BUSY;
  
  udp_socket_close(socket->socket);
  delete socket;
  return EB_OK;
}

eb_status_t eb_socket_poll(eb_socket_t socket) {
  unsigned char buf[UDP_SEGMENT_SIZE];
  udp_address_t who;
  int got;
  
  while ((got = udp_socket_recv_nb(socket->socket, &who, buf, sizeof(buf))) > 0) {
    // !!! process received packet
  }
  
  return (got < 0) ? EB_FAIL : EB_OK;
}

eb_descriptor_t eb_socket_descriptor(eb_socket_t socket) {
  return udp_socket_descriptor(socket->socket);
}

eb_status_t eb_device_open(eb_socket_t socket, eb_network_address_t ip_port, eb_device_t* result) {
  udp_address_t address;
  eb_device_t device;
  int got;
  int timeout = 15000000; // 15 seconds
  
  *result = 0;
  if (udp_socket_resolve(socket->socket, ip_port, &address) == -1)
    return EB_ADDRESS;
  
  /* Setup the device */
  device = new eb_device;
  device->socket = socket;
  device->address = address;
  device->queue_size = 0;
  device->cycles = 0;
  device->outstanding = 0;
  device->completed = 0;
  
  /* !!! should auto probe: */
  device->segment_words = UDP_SEGMENT_SIZE/4;
  device->portSz = 4;
  device->addrSz = 4;
  
  ++socket->devices;

  /* Check if the device speaks wishbone by executing an empty request */
  eb_device_flush(device);
  
  /* Enter a local blocking event loop */
  while (timeout > 0 && device->completed == 0) {
    got = udp_socket_block(socket->socket, timeout);
    assert (got >= 0 && got <= timeout);
    timeout -= got;
    
    eb_socket_poll(socket);
  }
  
  if (device->completed) {
    *result = device;
    return EB_OK;
  } else {
    eb_device_close(device);
    return EB_FAIL;
  }
}

eb_status_t eb_device_close(eb_device_t device) {
  if (device->cycles > 0)
    return EB_BUSY;
  if (!device->queue.empty())
    eb_device_flush(device);
  --device->socket->devices;
  delete device;
  return EB_OK;
}

eb_socket_t eb_device_socket(eb_device_t device) {
  return device->socket;
}

void eb_device_flush(eb_device_t socket) {
  assert (socket->queue_size <= UDP_SEGMENT_SIZE);
  
  unsigned char buf[UDP_SEGMENT_SIZE];
  // !!! build a packet
}

eb_cycle_t eb_cycle_open_read_write(eb_device_t device, eb_user_data_t user, eb_cycle_callback_t cb, eb_address_t base, eb_mode_t mode) {
  eb_cycle* cycle = new eb_cycle;
  assert (cycle != 0);
  
  ++device->cycles;
  cycle->device = device;
  
  cycle->callback  = cb;
  cycle->user_data = user;
  
  cycle->write_base = base;
  cycle->write_mode = mode;
  
  return cycle;
}

eb_cycle_t eb_cycle_open_read_only(eb_device_t device, eb_user_data_t user, eb_cycle_callback_t cb) {
  return eb_cycle_open_read_write(device, user, cb, 0, EB_UNDEFINED);
}

static unsigned int eb_cycle_size(eb_cycle_t cycle) {
  return 1 
    + (cycle->reads.empty()?0:1) 
    + (cycle->writes.empty()?0:1) 
    + cycle->reads.size()
    + cycle->writes.size();
}

void eb_cycle_close(eb_cycle_t cycle) {
  --cycle->device->cycles;
  
  unsigned int length = eb_cycle_size(cycle);
  if (length > cycle->device->segment_words) {  
    /* Operation is too big -- fail! */
    (*cycle->callback)(cycle->user_data, EB_OVERFLOW, 0, 0, 0);
    delete cycle;
    return;
  }
  
  if (cycle->device->queue_size + length > cycle->device->segment_words)
    eb_device_flush(cycle->device);
  
  cycle->device->queue_size += length;
  cycle->device->queue.push_back(cycle);
}

eb_device_t eb_cycle_device(eb_cycle_t cycle) {
  return cycle->device;
}

void eb_cycle_read(eb_cycle_t cycle, eb_address_t address) {
  cycle->reads.push_back(address);
}

void eb_cycle_write(eb_cycle_t cycle, eb_data_t data) {
  cycle->writes.push_back(data);
}

struct eb_read_proxy_t {
  eb_user_data_t     user;
  eb_read_callback_t cb;
};

static void eb_read_proxy(eb_user_data_t user, eb_status_t status, int reads_completed, int writes_completed, eb_data_t* result) {
  eb_read_proxy_t* proxy = (eb_read_proxy_t*)user;
  eb_data_t data = (reads_completed>0)?*result:0;
  (*proxy->cb)(proxy->user, status, data);
  delete proxy;
}

void eb_device_read(eb_device_t device, eb_address_t address, eb_user_data_t user, eb_read_callback_t cb) {
  eb_read_proxy_t* proxy = new eb_read_proxy_t;
  proxy->user = user;
  proxy->cb = cb;
  eb_cycle_t cycle = eb_cycle_open_read_only(device, proxy, &eb_read_proxy);
  eb_cycle_read(cycle, address);
  eb_cycle_close(cycle);
}

struct eb_write_proxy_t {
  eb_user_data_t      user;
  eb_write_callback_t cb;
};

static void eb_write_proxy(eb_user_data_t user, eb_status_t status, int reads_completed, int writes_completed, eb_data_t* result) {
  eb_write_proxy_t* proxy = (eb_write_proxy_t*)user;
  (*proxy->cb)(proxy->user, status);
  delete proxy;
}

void eb_device_write(eb_device_t device, eb_address_t address, eb_data_t data, eb_user_data_t user, eb_write_callback_t cb) {
  eb_write_proxy_t* proxy = new eb_write_proxy_t;
  proxy->user = user;
  proxy->cb = cb;
  eb_cycle_t cycle = eb_cycle_open_read_write(device, proxy, &eb_write_proxy, address, EB_FIFO);
  eb_cycle_write(cycle, data);
  eb_cycle_close(cycle);
}
