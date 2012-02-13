/* Copyright (C) 2011 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 */
#ifndef ETHERBONE_H
#define ETHERBONE_H

/*  uint32_t and friends */
#include <stdint.h>

/* Symbol visibility definitions */
#ifdef __WIN32
#ifdef ETHERBONE_IMPL
#define EB_PUBLIC __declspec(dllexport)
#define EB_PRIVATE
#else
#define EB_PUBLIC __declspec(dllimport)
#define EB_PRIVATE
#endif
#else
#define EB_PUBLIC
#define EB_PRIVATE __attribute__((visibility("hidden")))
#endif

/* Opaque structural types */
typedef struct eb_socket *eb_socket_t;
typedef struct eb_device *eb_device_t;
typedef struct eb_cycle *eb_cycle_t;

/* Configurable types */
typedef uint64_t eb_address_t;
typedef uint64_t eb_data_t;
/* Control types */
typedef const char *eb_network_address_t;
typedef int eb_descriptor_t;

/* Status codes */
typedef enum eb_status { 
  EB_OK=0, 
  EB_FAIL,
  EB_ADDRESS,
  EB_WIDTH,
  EB_OVERFLOW,
  EB_BUSY
} eb_status_t;
typedef enum eb_mode { 
  EB_UNDEFINED=-1, 
  EB_FIFO, 
  EB_LINEAR 
} eb_mode_t;

/* Bitmasks cannot be enums */
typedef unsigned int eb_flags_t;
#define EB_UDP_MODE	0
#define EB_FEC_MODE	1

/* Bitmasks cannot be enums */
typedef unsigned int eb_width_t;

#define EB_DATA8	1
#define EB_DATA16	2
#define EB_DATA32	4
#define EB_DATA64	8
#define EB_DATAX	0xf

#define EB_ADDR8	1
#define EB_ADDR16	2
#define EB_ADDR32	4
#define EB_ADDR64	8
#define EB_ADDRX	0xf

/* Callback types */
typedef void *eb_user_data_t;
typedef void (*eb_read_callback_t )(eb_user_data_t, eb_status_t, eb_data_t result);
typedef void (*eb_cycle_callback_t)(eb_user_data_t, eb_status_t, eb_data_t* result);

/* Handler descriptor */
typedef struct eb_handler {
  eb_address_t base;
  eb_address_t mask;
  
  eb_user_data_t data;
  
  eb_data_t (*read) (eb_user_data_t, eb_address_t, eb_width_t);
  void      (*write)(eb_user_data_t, eb_address_t, eb_width_t, eb_data_t);
} *eb_handler_t;

#ifdef __cplusplus
extern "C" {
#endif

/****************************************************************************/
/*                                 C99 API                                  */
/****************************************************************************/

/* Convert status to a human-readable printable string */
EB_PUBLIC
const char* eb_status(eb_status_t code);

/* Open an Etherbone socket for communicating with remote devices.
 * The port parameter is optional; 0 lets the operating system choose.
 * After opening the socket, poll must be hooked into an event loop.
 *
 * Return codes:
 *   OK		- successfully open the socket port
 *   FAIL	- operating system forbids access
 *   BUSY	- specified port is in use (only possible if port != 0)
 */
EB_PUBLIC
eb_status_t eb_socket_open(int           port, 
                           eb_flags_t    flags,
                           eb_socket_t*  result);

/* Close the Etherbone socket.
 * Any use of the socket after successful close will probably segfault!
 *
 * Return codes:
 *   OK		- successfully closed the socket and freed memory
 *   BUSY	- there are open devices on this socket
 */
EB_PUBLIC
eb_status_t eb_socket_close(eb_socket_t socket);

/* Poll the Etherbone socket for activity.
 * This function must be called regularly to receive incoming packets.
 * Either call poll very often or hook a read listener on its descriptor.
 * Callback functions are only executed from within the poll function.
 *
 * Return codes:
 *   OK		- poll complete; no further packets to process
 *   FAIL       - socket error (probably closed)
 */
EB_PUBLIC
eb_status_t eb_socket_poll(eb_socket_t socket);

/* Block until the socket is ready to be polled.
 * This function is useful if your program has no event loop of its own.
 * It returns the time expended while waiting.
 */
EB_PUBLIC
int eb_socket_block(eb_socket_t socket, int timeout_us);

/* Access the underlying file descriptor of the Etherbone socket.
 * THIS MUST NEVER BE READ, WRITTEN, CLOSED, OR MODIFIED IN ANY WAY!
 * It may be used to watch for read readiness to call poll.
 */
EB_PUBLIC
eb_descriptor_t eb_socket_descriptor(eb_socket_t socket);

/* Add a device to the virtual bus.
 * This handler receives all reads and writes to the specified address.
 * NOTE: the address range [0x0, 0x7fff) is reserved for internal use.
 *
 * Return codes:
 *   OK         - the handler has been installed
 *   FAIL       - out of memory
 *   ADDRESS    - the specified address range overlaps an existing device.
 */
EB_PUBLIC
eb_status_t eb_socket_attach(eb_socket_t socket, eb_handler_t handler);

/* Detach the device from the virtual bus.
 *
 * Return codes:
 *   OK         - the devices has be removed
 *   ADDRESS    - there is no device at the specified address.
 */
EB_PUBLIC
eb_status_t eb_socket_detach(eb_socket_t socket, eb_address_t address);

/* Open a remote Etherbone device.
 * This resolves the address and performs Etherbone end-point discovery.
 * From the mask of proposed bus address widths, one will be selected.
 * From the mask of proposed bus port    widths, one will be selected.
 * The device is probed every 3 seconds, 'attempts' times
 * The default port is taken as 0xEBD0.
 *
 * Return codes:
 *   OK		- the remote etherbone device is ready
 *   ADDRESS	- the network address could not be parsed
 *   FAIL	- the remote address did not identify itself as etherbone conformant
 *   WIDTH      - could not negotiate an acceptable data bus width
 */
EB_PUBLIC
eb_status_t eb_device_open(eb_socket_t           socket, 
                           eb_network_address_t  ip_port, 
                           eb_width_t            proposed_addr_widths,
                           eb_width_t            proposed_port_widths,
                           int                   attempts,
                           eb_device_t*          result);


/* Recover the negotiated data width of the target device.
 */
EB_PUBLIC
eb_width_t eb_device_width(eb_device_t device);

/* Close a remote Etherbone device.
 *
 * Return codes:
 *   OK		- associated memory has been freed
 *   BUSY	- there are outstanding wishbone cycles on this device
 */
EB_PUBLIC
eb_status_t eb_device_close(eb_device_t device);

/* Access the socket backing this device */
EB_PUBLIC
eb_socket_t eb_device_socket(eb_device_t device);

/* Flush commands queued on the device out the socket.
 */
EB_PUBLIC
void eb_device_flush(eb_device_t socket);

/* Begin a wishbone cycle on the remote device.
 * Read/write phases within a cycle hold the device locked.
 * All reads are executed first followed by all writes.
 * Until the cycle is closed, the operations are not queued.
 *
 * If data was read, the callback is run upon cycle completion.
 *
 * Status codes:
 *   OK		- the operation completed successfully
 *   ADDRESS    - a specified address exceeded device bus address width
 *   WIDTH      - a specified value exceeded device bus port width
 *   OVERFLOW	- too many operations queued for this cycle
 */
EB_PUBLIC
eb_cycle_t eb_cycle_open_read_only(eb_device_t          device, 
                                   eb_user_data_t       user,
                                   eb_cycle_callback_t  cb);

EB_PUBLIC
eb_cycle_t eb_cycle_open_read_write(eb_device_t          device, 
                                    eb_user_data_t       user,
                                    eb_cycle_callback_t  cb,
                                    eb_address_t         write_base,
                                    eb_mode_t            write_mode);

/* End a wishbone cycle.
 * This places the complete cycle at end of the device's send queue.
 * You will probably want to eb_flush_device soon after calling eb_cycle_close.
 */
EB_PUBLIC
void eb_cycle_close(eb_cycle_t cycle);

/* Access the device targetted by this cycle */
EB_PUBLIC
eb_device_t eb_cycle_device(eb_cycle_t cycle);

/* Prepare a wishbone read phase.
 * The given address is read from the remote device.
 * Upon return
 */
EB_PUBLIC
void eb_cycle_read(eb_cycle_t    cycle, 
                   eb_address_t  address);

/* Perform a wishbone write phase.
 * data is written to the current cursor on the remote device.
 * If the device was read-only, the operation is discarded.
 */
EB_PUBLIC
void eb_cycle_write(eb_cycle_t    cycle,
                    eb_data_t     data);

/* Perform a single-read wishbone cycle.
 * Semantically equivalent to cycle_open, cycle_read, cycle_close, device_flush.
 *
 * The given address is read on the remote device.
 * The callback cb(user, status, data) is invoked with the result.
 * The user parameter is passed through uninspected to the callback.
 *
 * Status codes:
 *   OK		- the operation completed successfully
 *   ADDRESS    - specified address exceeded device bus address width
 */
EB_PUBLIC
void eb_device_read(eb_device_t         device, 
                    eb_address_t        address,
                    eb_user_data_t      user,
                    eb_read_callback_t  cb);

/* Perform a single-write wishbone cycle.
 * Semantically equivalent to cycle_open, cycle_write, cycle_close, device_flush.
 *
 * data is written to the given address on the remote device.
 *
 * Status codes:
 *   OK		- the operation was sent successfully
 *   ADDRESS    - specified address exceeded device bus address width
 *   WIDTH      - specified value exceeded device bus port width
 */
EB_PUBLIC
eb_status_t eb_device_write(eb_device_t          device, 
                            eb_address_t         address,
                            eb_data_t            data);

#ifdef __cplusplus
}

/****************************************************************************/
/*                                 C++ API                                  */
/****************************************************************************/

namespace etherbone {

/* Copy the types into the namespace */
typedef eb_address_t address_t;
typedef eb_data_t data_t;
typedef eb_status_t status_t;
typedef eb_flags_t flags_t;
typedef eb_mode_t mode_t;
typedef eb_width_t width_t;
typedef eb_network_address_t network_address_t;
typedef eb_descriptor_t descriptor_t;

class Socket {
  public:
    Socket();
    
    status_t open(int port = 0, flags_t flags = 0);
    status_t close();
    status_t poll();
    descriptor_t descriptor() const;
  
  protected:
    eb_socket_t socket;
    Socket(eb_socket_t sock);
  
  friend class Device;
};

class Device {
  public:
    Device();
    
    status_t open(Socket socket, network_address_t address, width_t addr = EB_ADDRX, width_t port = EB_DATAX, int attempts = 5);
    status_t close();
    void flush();
    
    Socket socket() const;
    
    template <typename T>
    void read (address_t address, T* user, void (*cb)(T*, status_t, data_t));
    void read (address_t address);
    void write(address_t address, data_t data);

  protected:
    eb_device_t device;
  
  friend class Cycle;
};

class Cycle {
  public:
    // Start a cycle on the target device.
    template <typename T>
    Cycle(Device device, T* user, void (*cb)(T*, status_t, data_t*), address_t base = 0, mode_t mode = EB_UNDEFINED);
    Cycle(Device device, address_t base = 0, mode_t mode = EB_UNDEFINED);
    ~Cycle(); // End of cycle = destructor
    
    Cycle& read (address_t address);
    Cycle& write(data_t  data);
    
    Device device() const;
    
  protected:
    eb_cycle_t cycle;
    
    /* forbid copy and assignment */
    Cycle(const Cycle& o);
    Cycle& operator = (const Cycle& o);
};

/* Convenience templates to convert member functions into callback types */
template <typename T, void (T::*cb)(status_t, data_t)>
void proxy(T* object, status_t status, data_t data) {
  return (object->*cb)(status, data);
}
template <typename T, void (T::*cb)(status_t, data_t*)>
void proxy(T* object, status_t status, data_t* data) {
  return (object->*cb)(status, data);
}

/****************************************************************************/
/*                            C++ Implementation                            */
/****************************************************************************/

inline Socket::Socket(eb_socket_t sock)
 : socket(socket) { 
}

inline Socket::Socket()
 : socket(0) {
}

inline status_t Socket::open(int port, flags_t flags) {
  return eb_socket_open(port, flags, &socket);
}

inline status_t Socket::close() {
  status_t out = eb_socket_close(socket);
  if (out == EB_OK) socket = 0;
  return out;
}

inline status_t Socket::poll() {
  return eb_socket_poll(socket);
}
    
inline descriptor_t Socket::descriptor() const {
  return eb_socket_descriptor(socket);
}

inline Device::Device()
 : device(0) { 
}
    
inline status_t Device::open(Socket socket, network_address_t address, width_t addr, width_t port, int attempts) {
  return eb_device_open(socket.socket, address, addr, port, attempts, &device);
}
    
inline status_t Device::close() {
  status_t out = eb_device_close(device);
  if (out == EB_OK) device = 0;
  return out;
}

inline Socket Device::socket() const {
  return Socket(eb_device_socket(device));
}
    
inline void Device::flush() {
  return eb_device_flush(device);
}

inline void Device::write(address_t address, data_t data) {
  eb_device_write(device, address, data);
}
    
template <typename T>
inline void Device::read(address_t address, T* user, void (*cb)(T*, status_t, data_t)) {
  eb_device_read(device, address, user, reinterpret_cast<eb_read_callback_t>(cb));
}

inline void Device::read(address_t address) {
  eb_device_read(device, address, 0, 0);
}

template <typename T>
inline Cycle::Cycle(Device device, T* user, void (*cb)(T*, status_t, data_t*), address_t base, mode_t mode)
 : cycle(eb_cycle_open_read_write(device.device, user, reinterpret_cast<eb_cycle_callback_t>(cb), base, mode)) {
}

inline Cycle::Cycle(Device device, address_t base, mode_t mode)
 : cycle(eb_cycle_open_read_write(device.device, 0, 0, base, mode)) {
}

inline Cycle::~Cycle() { 
  eb_cycle_close(cycle); 
}

inline Cycle& Cycle::read(address_t address) {
  eb_cycle_read(cycle, address);
  return *this;
}
    
inline Cycle& Cycle::write(data_t data) {
  eb_cycle_write(cycle, data);
  return *this;
}

}

#endif

#endif