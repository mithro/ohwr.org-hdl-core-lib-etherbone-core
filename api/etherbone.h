/** @file etherbone.h
 *  @brief The public API of the Etherbone library.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  All Etherbone object types are opaque in this interface.
 *  Only those methods listed in this header comprise the public interface.
 *
 *  @author Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 *  @bug None!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */

#ifndef ETHERBONE_H
#define ETHERBONE_H

#include <stdint.h>   /* uint32_t ... */
#include <inttypes.h> /* EB_DATA_FMT ... */

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

/* Pointer type -- depends on memory implementation */
#ifdef EB_USE_MALLOC
#define EB_POINTER(typ) struct typ*
#define EB_NULL 0
#else
#define EB_POINTER(typ) uint16_t
#define EB_NULL ((uint16_t)-1)
#endif

/* Opaque structural types */
typedef EB_POINTER(eb_socket)    eb_socket_t;
typedef EB_POINTER(eb_device)    eb_device_t;
typedef EB_POINTER(eb_cycle)     eb_cycle_t;
typedef EB_POINTER(eb_operation) eb_operation_t;

/* Configurable maximum bus width supported */
#if defined(EB_64)
typedef uint64_t eb_address_t;
typedef uint64_t eb_data_t;
#define EB_ADDR_FMT PRIx64
#define EB_DATA_FMT PRIx64
#define EB_DATA_C UINT64_C
#define EB_ADDR_C UINT64_C
#elif defined(EB_32)
typedef uint32_t eb_address_t;
typedef uint32_t eb_data_t;
#define EB_ADDR_FMT PRIx32
#define EB_DATA_FMT PRIx32
#define EB_DATA_C UINT32_C
#define EB_ADDR_C UINT32_C
#elif defined(EB_16)
typedef uint16_t eb_address_t;
typedef uint16_t eb_data_t;
#define EB_ADDR_FMT PRIx16
#define EB_DATA_FMT PRIx16
#define EB_DATA_C UINT16_C
#define EB_ADDR_C UINT16_C
#elif defined(EB_8)
typedef uint8_t eb_address_t;
typedef uint8_t eb_data_t;
#define EB_ADDR_FMT PRIx8
#define EB_DATA_FMT PRIx8
#define EB_DATA_C UINT8_C
#define EB_ADDR_C UINT8_C
#else
/* The default maximum width is the machine word-size */
typedef uintptr_t eb_address_t;
typedef uintptr_t eb_data_t;
#define EB_ADDR_FMT PRIxPTR
#define EB_DATA_FMT PRIxPTR
#define EB_DATA_C UINT64_C
#define EB_ADDR_C UINT64_C
#endif

/* Status codes */
typedef int eb_status_t;
#define EB_OK		0
#define EB_FAIL		-1
#define EB_ADDRESS	-2
#define EB_WIDTH	-3
#define EB_OVERFLOW	-4
#define EB_BUSY		-5
#define EB_TIMEOUT	-6
#define EB_OOM          -7

/* Bitmasks cannot be enums */
typedef uint8_t eb_width_t;

#define EB_DATA8	0x01
#define EB_DATA16	0x02
#define EB_DATA32	0x04
#define EB_DATA64	0x08
#define EB_DATAX	0x0f

#define EB_ADDR8	0x10
#define EB_ADDR16	0x20
#define EB_ADDR32	0x40
#define EB_ADDR64	0x80
#define EB_ADDRX	0xf0

/* Callback types */
typedef void *eb_user_data_t;
typedef void (*eb_callback_t )(eb_user_data_t, eb_operation_t, eb_status_t);
typedef int eb_descriptor_t;
typedef void (*eb_descriptor_callback_t)(eb_user_data_t, eb_descriptor_t);

/* Handler descriptor */
typedef struct eb_handler {
  eb_address_t base;
  eb_address_t mask;
  
  eb_user_data_t data;
  
  eb_status_t (*read) (eb_user_data_t, eb_address_t, eb_width_t, eb_data_t*);
  eb_status_t (*write)(eb_user_data_t, eb_address_t, eb_width_t, eb_data_t);
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
 * The addr/port widths apply to virtual slaves on the bus.
 *
 * Return codes:
 *   OK		- successfully open the socket port
 *   FAIL	- operating system forbids access
 *   BUSY	- specified port is in use (only possible if port != 0)
 *   WIDTH      - supported_widths were invalid
 *   OOM        - out of memory
 */
EB_PUBLIC
eb_status_t eb_socket_open(const char*   port, 
                           eb_width_t    supported_widths,
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
 * The caller must first provide the current timestamp using eb_socket_settime.
 * Either call poll very often or hook a read listener on its descriptors.
 *
 * Return codes:
 *   OK		- poll complete; no further packets to process
 *   FAIL       - socket error (probably closed)
 */
EB_PUBLIC
eb_status_t eb_socket_poll(eb_socket_t socket);

/* Update the current timestamp cache (32-bit unsigned seconds since 1970).
 * This should be done before calls to poll.
 */
EB_PUBLIC
void eb_socket_settime(eb_socket_t socket, uint32_t now);

/* Block until the socket is ready to be polled.
 * This function is useful if your program has no event loop of its own.
 * If timeout_us == 0, return immediately. If timeout_us == -1, wait forever.
 * It returns the time expended while waiting.
 * Internally updates eb_socket_settime after call.
 */
EB_PUBLIC
int eb_socket_block(eb_socket_t socket, int timeout_us);

/* Access the underlying file descriptors of the Etherbone socket.
 * THESE MUST NEVER BE READ, WRITTEN, CLOSED, OR MODIFIED IN ANY WAY!
 * They may be used to watch for read readiness to call eb_socket_poll.
 */
EB_PUBLIC
void eb_socket_descriptor(eb_socket_t socket, eb_user_data_t user, eb_descriptor_callback_t cb); 

/* Access the next timestamp of the next timeout to expire.
 * The caller must first provide the current timestamp using eb_socket_settime.
 * When the returned time has been exceeded, poll should be run.
 */
EB_PUBLIC
uint32_t eb_socket_timeout(eb_socket_t socket);

/* Add a device to the virtual bus.
 * This handler receives all reads and writes to the specified address.
 * NOTE: the address range [0x0, 0x7fff) is reserved for internal use.
 *
 * Return codes:
 *   OK         - the handler has been installed
 *   OOM        - out of memory
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
 *   TIMEOUT    - the remote host did not respond with etherbone
 *   WIDTH      - could not negotiate an acceptable data bus width
 *   OOM        - out of memory
 */
EB_PUBLIC
eb_status_t eb_device_open(eb_socket_t           socket, 
                           const char*           address,
                           eb_width_t            proposed_widths,
                           int                   attempts,
                           eb_device_t*          result);


/* Recover the negotiated port and address width of the target device.
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
void eb_device_flush(eb_device_t device);

/* Begin a wishbone cycle on the remote device.
 * Read/write operations within a cycle hold the device locked.
 * Read/write operations are executed in the order they are queued.
 * Until the cycle is closed and flushed, the operations are not sent.
 * If there is insufficient memory to begin a cycle, EB_NULL is returned.
 * 
 * Your callback is called from either eb_socket_poll or eb_device_flush.
 * It receives these arguments: (user_data, operations, status)
 * 
 * If status != OK, the cycle was never sent to the remote bus.
 * If status == OK, the cycle was sent.
 *
 * When status == EB_OK, 'operations' report the wishbone ERR flag.
 * When status != EB_OK, 'operations' points to the offending operation.
 *
 * Status codes:
 *   OK		- operation completed successfully
 *   ADDRESS    - 1. a specified address exceeded device bus address width
 *                2. the address was not aligned to the operation granularity
 *   WIDTH      - 1. written value exceeded the operation granularity
 *                2. the granularity exceeded the device port width
 *   OVERFLOW	- too many operations queued for this cycle (wire limit)
 *   TIMEOUT    - remote system never responded to EB request
 *   FAIL       - remote host violated protocol
 *   OOM        - out of memory while queueing operations to the cycle
 */
EB_PUBLIC
eb_cycle_t eb_cycle_open(eb_device_t    device, 
                         eb_user_data_t user_data,
                         eb_callback_t  cb);

/* End a wishbone cycle.
 * This places the complete cycle at end of the device's send queue.
 * You will probably want to eb_flush_device soon after calling eb_cycle_close.
 */
EB_PUBLIC
void eb_cycle_close(eb_cycle_t cycle);

/* End a wishbone cycle.
 * This places the complete cycle at end of the device's send queue.
 * You will probably want to eb_flush_device soon after calling eb_cycle_close.
 * This method does NOT check individual wishbone operation error status.
 */
EB_PUBLIC
void eb_cycle_close_silently(eb_cycle_t cycle);

/* End a wishbone cycle.
 * The cycle is discarded, freed, and the callback never invoked.
 */
EB_PUBLIC
void eb_cycle_abort(eb_cycle_t cycle);

/* Access the device targetted by this cycle */
EB_PUBLIC
eb_device_t eb_cycle_device(eb_cycle_t cycle);

/* Prepare a wishbone read operation.
 * The given address is read from the remote device.
 * The result is written to the data address.
 * If data == 0, the result can still be accessed via eb_operation_data.
 *
 * The operation width is max {x in width: x <= data_width(device) }.
 * Your address must be aligned to the operation width.
 */
EB_PUBLIC
void eb_cycle_read(eb_cycle_t    cycle, 
                   eb_address_t  address,
                   eb_width_t    width,
                   eb_data_t*    data);
EB_PUBLIC
void eb_cycle_read_config(eb_cycle_t    cycle, 
                          eb_address_t  address,
                          eb_width_t    width,
                          eb_data_t*    data);

/* Perform a wishbone write operation.
 * The given address is written on the remote device.
 * 
 * The operation width is max {x in width: x <= data_width(device) }.
 * Your address must be aligned to this operation and the data must fit.
 */
EB_PUBLIC
void eb_cycle_write(eb_cycle_t    cycle,
                    eb_address_t  address,
                    eb_width_t    width,
                    eb_data_t     data);
EB_PUBLIC
void eb_cycle_write_config(eb_cycle_t    cycle,
                           eb_address_t  address,
                           eb_width_t    width,
                           eb_data_t     data);

/* Convenience function for single-write cycle.
 * Can return EB_OOM.
 */
EB_PUBLIC
eb_status_t eb_device_read(eb_device_t    device, 
                           eb_address_t   address,
                           eb_width_t    width,
                           eb_data_t*     data, 
                           eb_user_data_t user, 
                           eb_callback_t  cb);

/* Convenience function for single-read cycle.
 * Can return EB_OOM.
 */
EB_PUBLIC
eb_status_t eb_device_write(eb_device_t    device, 
                            eb_address_t   address, 
                            eb_width_t    width,
                            eb_data_t      data, 
                            eb_user_data_t user, 
                            eb_callback_t  cb);

/* Operation result accessors */

/* The next operation in the list. EB_NULL = end-of-list */
EB_PUBLIC eb_operation_t eb_operation_next(eb_operation_t op);

/* Was this operation a read? 1=read, 0=write */
EB_PUBLIC int eb_operation_is_read(eb_operation_t op);
/* Was this operation onthe config space? 1=config, 0=wb-bus */
EB_PUBLIC int eb_operation_is_config(eb_operation_t op);
/* Did this operation have an error? 1=error, 0=success */
EB_PUBLIC int eb_operation_had_error(eb_operation_t op);
/* What was the address of this operation? */
EB_PUBLIC eb_address_t eb_operation_address(eb_operation_t op);
/* What was the read or written value of this operation? */
EB_PUBLIC eb_data_t eb_operation_data(eb_operation_t op);
/* What was the width of this operation? */
EB_PUBLIC eb_width_t eb_operation_width(eb_operation_t op);

#ifdef __cplusplus
}

#include <vector>

/****************************************************************************/
/*                                 C++ API                                  */
/****************************************************************************/

namespace etherbone {

/* Copy the types into the namespace */
typedef eb_address_t address_t;
typedef eb_data_t data_t;
typedef eb_status_t status_t;
typedef eb_width_t width_t;
typedef eb_descriptor_t descriptor_t;

class Handler {
  public:
    virtual status_t read (address_t address, width_t width, data_t* data) = 0;
    virtual status_t write(address_t address, width_t width, data_t  data) = 0;
};

class Socket {
  public:
    Socket();
    
    status_t open(const char* port = 0, width_t width = EB_DATAX|EB_ADDRX);
    status_t close();
    
    /* attach/detach a virtual device */
    status_t attach(address_t base, address_t mask, Handler* handler);
    status_t detach(address_t address);
    
    status_t poll();
    int block(int timeout_us);
    
    /* These can be used to implement your own 'block': */
    uint32_t timeout() const;
    EB_PUBLIC std::vector<descriptor_t> descriptor() const;
    void settime(uint32_t now);
    
  protected:
    Socket(eb_socket_t sock);
    eb_socket_t socket;
  
  friend class Device;
};

class Device {
  public:
    Device();
    
    status_t open(Socket socket, const char* address, width_t width = EB_ADDRX|EB_DATAX, int attempts = 5);
    status_t close();
    void flush();
    
    const Socket socket() const;
    Socket socket();
    
    width_t width() const;
    
  protected:
    Device(eb_device_t device);
    eb_device_t device;
  
  friend class Cycle;
};

class Cycle {
  public:
    // Start a cycle on the target device.
    template <typename T>
    Cycle(Device device, T* user, void (*cb)(T*, eb_operation_t, eb_status_t));
    Cycle(Device device);
    ~Cycle(); // End of cycle = destructor
    
    void abort();
    void silent_finish();
    
    Cycle& read (address_t address, width_t width = EB_DATAX, data_t* data = 0);
    Cycle& write(address_t address, width_t width, data_t  data);
    
    Cycle& read_config (address_t address, width_t width = EB_DATAX, data_t* data = 0);
    Cycle& write_config(address_t address, width_t width, data_t  data);
    
    const Device device() const;
    Device device();
    
  protected:
    eb_cycle_t cycle;
    
    /* forbid copy and assignment */
    Cycle(const Cycle& o);
    Cycle& operator = (const Cycle& o);
};

class Operation {
  public:
    bool is_null  () const;
    
    /* Only call these if is_null is false */
    bool is_read  () const;
    bool is_config() const;
    bool had_error() const;
    
    address_t address() const;
    data_t    data   () const;
    width_t   width  () const;
    
    const Operation next() const;
    Operation next();
    
  protected:
    Operation(eb_operation_t op);
    
    eb_operation_t operation;

  /* Convenience templates to convert member functions into callback type */
  template <typename T, void (T::*cb)(Operation, status_t)>
  friend void proxy(T* object, eb_operation_t op, eb_status_t status) {
    return (object->*cb)(Operation(op), status);
  }
};

/****************************************************************************/
/*                            C++ Implementation                            */
/****************************************************************************/

inline Socket::Socket(eb_socket_t sock)
 : socket(sock) { 
}

inline Socket::Socket()
 : socket(EB_NULL) {
}

inline status_t Socket::open(const char* port, width_t width) {
  return eb_socket_open(port, width, &socket);
}

inline status_t Socket::close() {
  status_t out = eb_socket_close(socket);
  if (out == EB_OK) socket = EB_NULL;
  return out;
}

/* Proxy */
EB_PUBLIC eb_status_t eb_proxy_read_handler(eb_user_data_t data, eb_address_t address, eb_width_t width, eb_data_t* ptr);
EB_PUBLIC eb_status_t eb_proxy_write_handler(eb_user_data_t data, eb_address_t address, eb_width_t width, eb_data_t value);

inline status_t Socket::attach(address_t base, address_t mask, Handler* handler) {
  struct eb_handler h;
  h.base = base;
  h.mask = mask;
  h.data = handler;
  h.read  = &eb_proxy_read_handler;
  h.write = &eb_proxy_write_handler;
  return eb_socket_attach(socket, &h);
}

inline status_t Socket::detach(address_t address) {
  return eb_socket_detach(socket, address);
}

inline status_t Socket::poll() {
  return eb_socket_poll(socket);
}

inline int Socket::block(int timeout_us) {
  return eb_socket_block(socket, timeout_us);
}

inline uint32_t Socket::timeout() const {
  return eb_socket_timeout(socket);
}

inline void Socket::settime(uint32_t now) {
  return eb_socket_settime(socket, now);
}

inline Device::Device(eb_device_t dev)
 : device(dev) {
}

inline Device::Device()
 : device(EB_NULL) { 
}
    
inline status_t Device::open(Socket socket, const char* address, width_t width, int attempts) {
  return eb_device_open(socket.socket, address, width, attempts, &device);
}
    
inline status_t Device::close() {
  status_t out = eb_device_close(device);
  if (out == EB_OK) device = EB_NULL;
  return out;
}

inline const Socket Device::socket() const {
  return Socket(eb_device_socket(device));
}

inline Socket Device::socket() {
  return Socket(eb_device_socket(device));
}

inline width_t Device::width() const {
  return eb_device_width(device);
}

inline void Device::flush() {
  return eb_device_flush(device);
}

template <typename T>
inline Cycle::Cycle(Device device, T* user, void (*cb)(T*, eb_operation_t, status_t))
 : cycle(eb_cycle_open(device.device, user, reinterpret_cast<eb_callback_t>(cb))) {
}

inline Cycle::Cycle(Device device)
 : cycle(eb_cycle_open(device.device, 0, 0)) {
}

inline Cycle::~Cycle() {
  if (cycle != EB_NULL)
    eb_cycle_close(cycle); 
}

inline void Cycle::abort() {
  if (cycle != EB_NULL)
    eb_cycle_abort(cycle);
  cycle = EB_NULL;
}

inline void Cycle::silent_finish() {
  if (cycle != EB_NULL)
    eb_cycle_close_silently(cycle);
  cycle = EB_NULL;
}

inline Cycle& Cycle::read(address_t address, width_t width, data_t* data) {
  eb_cycle_read(cycle, address, width, data);
  return *this;
}

inline Cycle& Cycle::write(address_t address, width_t width, data_t data) {
  eb_cycle_write(cycle, address, width, data);
  return *this;
}

inline Cycle& Cycle::read_config(address_t address, width_t width, data_t* data) {
  eb_cycle_read_config(cycle, address, width, data);
  return *this;
}

inline Cycle& Cycle::write_config(address_t address, width_t width, data_t data) {
  eb_cycle_write_config(cycle, address, width, data);
  return *this;
}

inline const Device Cycle::device() const {
  return Device(eb_cycle_device(cycle));
}

inline Device Cycle::device() {
  return Device(eb_cycle_device(cycle));
}

inline Operation::Operation(eb_operation_t op)
 : operation(op) {
}

inline bool Operation::is_null() const {
  return operation == EB_NULL;
}

inline bool Operation::is_read() const {
  return eb_operation_is_read(operation);
}

inline bool Operation::is_config() const {
  return eb_operation_is_config(operation);
}

inline bool Operation::had_error() const {
  return eb_operation_had_error(operation);
}

inline address_t Operation::address() const {
  return eb_operation_address(operation);
}

inline width_t Operation::width() const {
  return eb_operation_width(operation);
}

inline data_t Operation::data() const {
  return eb_operation_data(operation);
}

inline Operation Operation::next() {
  return Operation(eb_operation_next(operation));
}

inline const Operation Operation::next() const {
  return Operation(eb_operation_next(operation));
}

}

#endif

#endif
