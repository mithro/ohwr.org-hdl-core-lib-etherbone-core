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

#define FIFO_BIT 0x1000

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
  device->portSz = 2;
  device->addrSz = 2;
  
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

static const unsigned char* read_uint8(const unsigned char* ptr, uint8_t* x) {
  uint8_t out = 0;
  out <<= 8; out |= *ptr++;
  *x = out;
  return ptr;
}

static const unsigned char* read_uint16(const unsigned char* ptr, uint16_t* x) {
  uint16_t out = 0;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  *x = out;
  return ptr;
}

static const unsigned char* read_uint32(const unsigned char* ptr, uint32_t* x) {
  uint32_t out = 0;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  *x = out;
  return ptr;
}

static const unsigned char* read_uint64(const unsigned char* ptr, uint64_t* x) {
  uint64_t out = 0;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  out <<= 8; out |= *ptr++;
  *x = out;
  return ptr;
}

static const unsigned char* read_word(const unsigned char* ptr, unsigned int size, uint64_t* x) {
  if (size == 64)
    return read_uint64(ptr, x);
  else { // pad all other lengths to 32
    uint32_t y;
    return read_uint32(ptr, &y);
    *x = y;
  }
}

static const unsigned char* read_pad(const unsigned char* ptr, unsigned int size) {
  if (size == 64)
    return ptr + 4;
  else
    return ptr;
}

static const unsigned char* read_skip(const unsigned char* ptr, unsigned int size, unsigned int count) {
  if (size == 64)
    return ptr + (count*8);
  else
    return ptr + (count*4);
}

static unsigned char* write_uint8(unsigned char* ptr, uint8_t x) {
  ptr += 1;
  *--ptr = x; x >>= 8;
  return ptr + 1;
}

static unsigned char* write_uint16(unsigned char* ptr, uint16_t x) {
  ptr += 2;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  return ptr + 2;
}

static unsigned char* write_uint32(unsigned char* ptr, uint32_t x) {
  ptr += 4;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  return ptr + 4;
}

static unsigned char* write_uint64(unsigned char* ptr, uint64_t x) {
  ptr += 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  *--ptr = x; x >>= 8;
  return ptr+8;
}

static unsigned char* write_word(unsigned char* ptr, unsigned int size, uint64_t x) {
  if (size == 64)
    return write_uint64(ptr, x);
  else // pad all other lengths to 32
    return write_uint32(ptr, x);
}

static unsigned char* write_pad(unsigned char* ptr, unsigned int size) {
  if (size == 64)
    return write_uint32(ptr, 0);
  else
    return ptr;
}

eb_status_t eb_socket_poll(eb_socket_t socket) {
  unsigned char buf[UDP_SEGMENT_SIZE];
  unsigned char obuf[UDP_SEGMENT_SIZE];
  udp_address_t who;
  int got;
  
  while ((got = udp_socket_recv_nb(socket->socket, &who, buf, sizeof(buf))) > 0) {
    uint64_t statusAddr;
    uint16_t magic;
    uint8_t version;
    uint8_t szField;
    unsigned int portSz, addrSz, biggest, size;
    const unsigned char* c = buf;
    const unsigned char* e = buf+got;
    unsigned char* o = obuf;
    
    if (c + 4 > e) continue; /* Ignore too short packet */
    
    c = read_uint16(c, &magic);
    if (magic != 0x4e6f) continue;
    c = read_uint8(c, &version);
    c = read_uint8(c, &szField);
    
    /* Clone the header in the reply */
    o = write_uint16(o, magic);
    o = write_uint8(o, version);
    o = write_uint8(o, szField);
    
    addrSz = szField >> 4;
    portSz = szField & 0xf;
    version >>= 4;
    if (version == 0) continue; /* There is no v0 Etherbone */
    
    if (addrSz > portSz)
      biggest = addrSz;
    else
      biggest = portSz;
    
    switch (biggest) {
    case 0: size =  8; break;
    case 1: size = 16; break;
    case 2: size = 32; break;
    case 3: size = 64; break;
    default: continue; /* Ignore unsupoprted bitwidth */
    }
    
    if (read_skip(c, size, 1) > e) continue;
    c = read_word(c, size, &statusAddr);
    o = write_word(o, size, 0); /* Reply has no status address */
    
    /* Detect and respond to unsupported version */
    if (version > 1) {
      if (statusAddr != 0) {
        /* Write -1 to the status address to indicate protocol mismatch */
        o = write_uint16(o, 0);
        o = write_uint16(o, 1);
        o = write_pad(o, size);
        
        o = write_word(o, size, statusAddr);
        o = write_word(o, size, -1);
        
        udp_socket_send(socket->socket, &who, obuf, o - obuf);
      }
      continue;
    }
    
    while (read_skip(c, size, 1) != e) {
      uint16_t rfield, wfield;
      unsigned int rcount, wcount;
      unsigned int reserve;
      eb_mode_t read_mode, write_mode;
      uint64_t data, addr, retaddr;
      
      c = read_uint16(c, &rfield);
      c = read_uint16(c, &wfield);
      c = read_pad(c, size);
      
      read_mode  = ((rfield&FIFO_BIT)!=0)?EB_FIFO:EB_LINEAR;
      write_mode = ((wfield&FIFO_BIT)!=0)?EB_FIFO:EB_LINEAR;
      rcount = rfield & (FIFO_BIT-1);
      wcount = wfield & (FIFO_BIT-1);
      
      reserve = 0;
      if (rcount > 0) ++reserve;
      if (wcount > 0) ++reserve;
      reserve += rcount;
      reserve += wcount;
      if (read_skip(c, size, reserve) > e) break; /* Stop processing if short cycle */
      
      if (rcount > 0) {
        /* Prepare reply header */
        o = write_uint16(o, 0);
        o = write_uint16(o, rfield);
        o = write_pad(o, size);
        
        c = read_word(c, size, &retaddr);
        o = write_word(o, size, retaddr);
        for (unsigned int i = 0; i < rcount; ++i) {
          c = read_word(c, size, &addr);
          // data = read(addr)
          o = write_word(o, size, data);
        }
      }
      
      if (wcount > 0) {
        c = read_word(c, size, &retaddr);
        for (unsigned int i = 0; i < wcount; ++i) {
          c = read_word(c, size, &data);
          // Do write(retaddr, data)
          if (write_mode == EB_LINEAR)
            switch (portSz) {
            case 0: retaddr += 1; break;
            case 1: retaddr += 2; break;
            case 2: retaddr += 4; break;
            case 3: retaddr += 8; break;
            }
        }
      }
    }
    
    /* Send the reply */
    udp_socket_send(socket->socket, &who, obuf, o - obuf);
  }
  
  return (got < 0) ? EB_FAIL : EB_OK;
}

void eb_device_flush(eb_device_t device) {
  assert (device->queue_size <= device->segment_words);
  
  unsigned char buf[UDP_SEGMENT_SIZE];
  unsigned char* c = buf;
  
  unsigned int size, biggest;
  
  if (device->addrSz > device->portSz)
    biggest = device->addrSz;
  else
    biggest = device->portSz;
  
  switch (biggest) {
  case 0: size =  8; break;
  case 1: size = 16; break;
  case 2: size = 32; break;
  case 3: size = 64; break;
  default: return; /* Bad input -> do nothing */
  }
  
  /* Header */
  c = write_uint16(c, 0x4e6f);
  c = write_uint8(c, 0x10);
  c = write_uint8(c, (device->addrSz << 4) | device->portSz);
  c = write_pad(c, size);
  c = write_word(c, size, 0); // !!! status address
  
  for (unsigned int i = 0; i < device->queue.size(); ++i) {
    eb_cycle_t cycle = device->queue[i];
    unsigned int rcount = cycle->reads.size();
    unsigned int wcount = cycle->writes.size();
    /* These must fit in 12 bits */
    assert (rcount < 4096);
    assert (wcount < 4096);
    /* Cycle header */
    c = write_uint16(c, FIFO_BIT | rcount); /* Always use FIFO mode for reads */
    c = write_uint16(c, ((cycle->write_mode==EB_FIFO)?FIFO_BIT:0) | wcount); 
    c = write_pad(c, size);
    
    /* Write reads */
    if (rcount > 0) {
      c = write_word(c, size, 0); // !!! read base address
      for (unsigned int j = 0; j < rcount; ++j) {
        eb_address_t addr = cycle->reads[j];
        c = write_word(c, size, addr);
      }
    }
    
    if (wcount > 0) {
      c = write_word(c, size, cycle->write_base);
      for (unsigned int j = 0; j < wcount; ++j) {
        eb_data_t data = cycle->writes[j];
        c = write_word(c, size, data);
      }
    }
  }
  
  udp_socket_send(device->socket->socket, &device->address, buf, c - buf);
  device->queue.clear();
  device->queue_size = 0;
  ++device->outstanding;
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
