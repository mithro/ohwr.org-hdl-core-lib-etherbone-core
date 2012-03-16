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

#define EB_PROTOCOL_VERSION	1
#define EB_ABI_VERSION		0x01	/* incremented on incompatible changes */

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
#define EB_MEMORY_MODEL 0x0001U
#else
#define EB_POINTER(typ) uint16_t
#define EB_NULL ((uint16_t)-1)
#define EB_MEMORY_MODEL 0x0000U
#endif

/* Opaque structural types */
typedef EB_POINTER(eb_socket)    eb_socket_t;
typedef EB_POINTER(eb_device)    eb_device_t;
typedef EB_POINTER(eb_cycle)     eb_cycle_t;
typedef EB_POINTER(eb_operation) eb_operation_t;

/* Configurable maximum bus width supported */
#if defined(EB_FORCE_64)
typedef uint64_t eb_address_t;
typedef uint64_t eb_data_t;
#define EB_ADDR_FMT PRIx64
#define EB_DATA_FMT PRIx64
#define EB_DATA_C UINT64_C
#define EB_ADDR_C UINT64_C
#elif defined(EB_FORCE_32)
typedef uint32_t eb_address_t;
typedef uint32_t eb_data_t;
#define EB_ADDR_FMT PRIx32
#define EB_DATA_FMT PRIx32
#define EB_DATA_C UINT32_C
#define EB_ADDR_C UINT32_C
#elif defined(EB_FORCE_16)
typedef uint16_t eb_address_t;
typedef uint16_t eb_data_t;
#define EB_ADDR_FMT PRIx16
#define EB_DATA_FMT PRIx16
#define EB_DATA_C UINT16_C
#define EB_ADDR_C UINT16_C
#else
/* The default maximum width is the machine word-size */
typedef uintptr_t eb_address_t;
typedef uintptr_t eb_data_t;
#define EB_ADDR_FMT PRIxPTR
#define EB_DATA_FMT PRIxPTR
#define EB_DATA_C UINT64_C
#define EB_ADDR_C UINT64_C
#endif

/* Identify the library ABI this header must match */
#define EB_BUS_MODEL	(0x0010U * sizeof(eb_address_t)) + (0x0001U * sizeof(eb_data_t))
#define EB_ABI_CODE	((EB_ABI_VERSION << 8) + EB_BUS_MODEL + EB_MEMORY_MODEL)

/* Status codes */
typedef int eb_status_t;
#define EB_OK		0
#define EB_FAIL		-1
#define EB_ADDRESS	-2
#define EB_WIDTH	-3
#define EB_OVERFLOW	-4
#define EB_ENDIAN	-5
#define EB_BUSY		-6
#define EB_TIMEOUT	-7
#define EB_OOM          -8
#define EB_ABI		-9

/* A bitmask containing values from EB_DATAX | EB_ADDRX */
typedef uint8_t eb_width_t;
/* A bitmask containing values from EB_DATAX | EB_ENDIAN_MASK */
typedef uint8_t eb_format_t;

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

#define EB_ENDIAN_MASK	0x30
#define	EB_BIG_ENDIAN	0x10
#define EB_LITTLE_ENDIAN 0x20

/* Callback types */
typedef void *eb_user_data_t;
typedef void (*eb_callback_t )(eb_user_data_t, eb_device_t, eb_operation_t, eb_status_t);
typedef int eb_descriptor_t;
typedef int (*eb_descriptor_callback_t)(eb_user_data_t, eb_descriptor_t);

typedef struct sdwb_bus {
  uint8_t  magic[16];
  uint64_t bus_end;
  uint16_t sdwb_records;
  uint8_t  sdwb_ver_major;
  uint8_t  sdwb_ver_minor;
  uint32_t bus_vendor;
  uint32_t bus_device;
  uint32_t bus_version;
  uint32_t bus_date;
  uint32_t bus_flags;
  uint8_t  description[16]; 
} *sdwb_bus_t;

typedef struct sdwb_device {
  uint64_t wbd_begin;
  uint64_t wbd_end;
  uint64_t sdwb_child;
#define WBD_FLAG_PRESENT	0x01
#define WBD_FLAG_LITTLE_ENDIAN	0x02
#define WBD_FLAG_HAS_CHILD	0x04
  uint8_t  wbd_flags;
  uint8_t  wbd_width;
  uint8_t  abi_ver_major;
  uint8_t  abi_ver_minor;
  uint32_t abi_class;
  uint32_t dev_vendor;
  uint32_t dev_device;
  uint32_t dev_version;
  uint32_t dev_date;
  uint8_t  description[16];
} *sdwb_device_t;

/* Complete bus description */
typedef struct sdwb {
  struct sdwb_bus    bus;
  struct sdwb_device device[1]; /* bus.sdwb_records-1 elements (not 1) */
} *sdwb_t;

/* Handler descriptor */
typedef struct eb_handler {
  /* This pointer must remain valid until after you detach the device */
  sdwb_device_t device;
  
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
 * Open sockets must be hooked into an event loop; see eb_socket_{run,check}.
 * 
 * The abi_code must be EB_ABI_CODE. This confirms library compatability.
 * The port parameter is optional; 0 lets the operating system choose.
 * Supported_widths list bus widths acceptable to the local Wishbone bus.
 *   EB_ADDR32|EB_ADDR8|EB_DATAX means 8/32-bit addrs and 8/16/32/64-bit data.
 *   Devices opened by this socket only negotiate a subset of these widths.
 *   Virtual slaves attached to the socket never see a width excluded here.
 *
 * Return codes:
 *   OK		- successfully open the socket port
 *   FAIL	- operating system forbids access
 *   BUSY	- specified port is in use (only possible if port != 0)
 *   WIDTH      - supported_widths were invalid
 *   OOM        - out of memory
 *   ABI        - library is not compatible with application
 */
EB_PUBLIC
eb_status_t eb_socket_open(uint16_t      abi_code,
                           const char*   port, 
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

/* Wait for an event on the socket and process it.
 * This function is useful if your program has no event loop of its own.
 * If timeout_us == 0, return immediately. If timeout_us == -1, wait forever.
 * It returns the time expended while waiting.
 */
EB_PUBLIC
int eb_socket_run(eb_socket_t socket, int timeout_us);

/* Integrate this Etherbone socket into your own event loop.
 *
 * You must call eb_socket_check whenever:
 *   1. An etherbone timeout expires (eb_socket_timeout tells you when this is)
 *   2. An etherbone socket is ready to read (eb_socket_descriptors lists them)
 * You must provide eb_socket_check with:
 *   1. The current time
 *   2. A function that returns '1' if a socket is ready to read
 *
 * YOU MAY NOT CLOSE OR MODIFY ETHERBONE SOCKET DESCRIPTORS IN ANY WAY.
 */
EB_PUBLIC
void eb_socket_check(eb_socket_t socket, uint32_t now, eb_user_data_t user, eb_descriptor_callback_t ready);

/* Calls (*list)(user, fd) for every descriptor the socket uses. */
EB_PUBLIC
void eb_socket_descriptors(eb_socket_t socket, eb_user_data_t user, eb_descriptor_callback_t list); 

/* Returns 0 if there are no timeouts pending, otherwise the time in UTC seconds. */
EB_PUBLIC
uint32_t eb_socket_timeout(eb_socket_t socket);

/* Add a device to the virtual bus.
 * This handler receives all reads and writes to the specified address.
 * The handler structure passed to eb_socket_attach need not be preserved.
 * The sdwb_device MUST be preserved until the device is detached.
 * NOTE: the address range [0x0, 0x4000) is reserved for internal use.
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
eb_status_t eb_socket_detach(eb_socket_t socket, sdwb_device_t device);

/* Open a remote Etherbone device at 'address' (default port 0xEBD0).
 * Negotiation of bus widths is attempted every 3 seconds, 'attempts' times.
 * The proposed_widths is intersected with the remote and local socket widths.
 * From the remaining widths, the largest address and data width is chosen.
 *
 * Return codes:
 *   OK		- the remote etherbone device is ready
 *   ADDRESS	- the network address could not be parsed
 *   TIMEOUT    - timeout waiting for etherbone response
 *   FAIL       - failure of the transport layer (remote host down?)
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
 * Any inflight or ready-to-send cycles will receive EB_TIMEOUT.
 *
 * Return codes:
 *   OK	        - associated memory has been freed
 *   BUSY       - there are unclosed wishbone cycles on this device
 */
EB_PUBLIC
eb_status_t eb_device_close(eb_device_t device);

/* Access the socket backing this device */
EB_PUBLIC
eb_socket_t eb_device_socket(eb_device_t device);

/* Flush all queued cycles to the remote device.
 * Multiple cycles can be packed into a single Etherbone packet.
 * Until this method is called, cycles are only queued, not sent.
 *
 * Return codes:
 *   OK		- queued packets have been sent
 *   FAIL	- the device has a broken link
 */
EB_PUBLIC
eb_status_t eb_device_flush(eb_device_t device);

/* Begin a wishbone cycle on the remote device.
 * Read/write operations within a cycle hold the device locked.
 * Read/write operations are executed in the order they are queued.
 * Until the cycle is closed and device flushed, the operations are not sent.
 *
 * Returns:
 *    FAIL      - device is being closed, cannot create new cycles
 *    OOM       - insufficient memory
 *    OK        - cycle created successfully (your callback will be run)
 * 
 * Your callback will be called exactly once from either:
 *   eb_socket_{run,check} or eb_device_{flush,close}
 * It receives these arguments: cb(user_data, device, operations, status)
 * 
 * If status != OK, the cycle was never sent to the remote bus.
 * If status == OK, the cycle was sent.
 *
 * When status == EB_OK, 'operations' report the wishbone ERR flag.
 * When status != EB_OK, 'operations' points to the offending operation.
 *
 * Callback status codes:
 *   OK		- cycle was executed successfully
 *   ADDRESS    - 1. a specified address exceeded device bus address width
 *                2. the address was not aligned to the operation granularity
 *   WIDTH      - 1. written value exceeded the operation granularity
 *                2. the granularity exceeded the device port width
 *   ENDIAN     - operation format was not word size and no endian was specified
 *   OVERFLOW	- too many operations queued for this cycle (wire limit)
 *   TIMEOUT    - remote system never responded to EB request
 *   FAIL       - remote host violated protocol
 *   OOM        - out of memory while queueing operations to the cycle
 */
EB_PUBLIC
eb_status_t eb_cycle_open(eb_device_t    device, 
                          eb_user_data_t user_data,
                          eb_callback_t  cb,
                          eb_cycle_t*    result);

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
 * The operation size is max {x in format: x <= data_width(device) }.
 * When the size is not the device data width, format must include an endian.
 * Your address must be aligned to the operation size.
 */
EB_PUBLIC
void eb_cycle_read(eb_cycle_t    cycle, 
                   eb_address_t  address,
                   eb_format_t   format,
                   eb_data_t*    data);
EB_PUBLIC
void eb_cycle_read_config(eb_cycle_t    cycle, 
                          eb_address_t  address,
                          eb_format_t   format,
                          eb_data_t*    data);

/* Perform a wishbone write operation.
 * The given address is written on the remote device.
 * 
 * The operation size is max {x in width: x <= data_width(device) }.
 * When the size is not the device data width, format must include an endian.
 * Your address must be aligned to this operation size and the data must fit.
 */
EB_PUBLIC
void eb_cycle_write(eb_cycle_t    cycle,
                    eb_address_t  address,
                    eb_format_t   format,
                    eb_data_t     data);
EB_PUBLIC
void eb_cycle_write_config(eb_cycle_t    cycle,
                           eb_address_t  address,
                           eb_format_t   format,
                           eb_data_t     data);

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
/* What was the format of this operation? */
EB_PUBLIC eb_format_t eb_operation_format(eb_operation_t op);

/* Read the SDWB information from the remote bus.
 * If there is not enough memory to initiate the request, EB_OOM is returned.
 * To scan the root bus, Etherbone config space is used to locate the SDWB record.
 * When scanning a child bus, supply the bridge's sdwb_device record.
 *
 * All fields in the processed structures are in machine native endian.
 * When scanning a child bus, nested addresses are automatically converted.
 *
 * Your callback is called from eb_socket_{run,check} or eb_device_{close,flush}.
 * It receives these arguments: (user_data, device, sdwb, status)
 *
 * If status != OK, the SDWB information could not be retrieved.
 * If status == OK, the structure was retrieved.
 *
 * The sdwb object passed to your callback is only valid until you return.
 * If you need persistent information, you must copy the memory yourself.
 */
typedef void (*sdwb_callback_t)(eb_user_data_t, eb_device_t device, sdwb_t, eb_status_t);
EB_PUBLIC eb_status_t eb_sdwb_scan_bus(eb_device_t device, sdwb_device_t bridge, eb_user_data_t data, sdwb_callback_t cb);
EB_PUBLIC eb_status_t eb_sdwb_scan_root(eb_device_t device, eb_user_data_t data, sdwb_callback_t cb);

#ifdef __cplusplus
}

/****************************************************************************/
/*                                 C++ API                                  */
/****************************************************************************/

namespace etherbone {

/* Copy the types into the namespace */
typedef eb_address_t address_t;
typedef eb_data_t data_t;
typedef eb_format_t format_t;
typedef eb_status_t status_t;
typedef eb_width_t width_t;
typedef eb_descriptor_t descriptor_t;

class Socket;
class Device;
class Cycle;
class Operation;

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
    status_t attach(sdwb_device_t device, Handler* handler);
    status_t detach(sdwb_device_t device);
    
    int run(int timeout_us);
    
    /* These can be used to implement your own 'block': */
    uint32_t timeout() const;
    void descriptors(eb_user_data_t user, eb_descriptor_callback_t list) const;
    void check(uint32_t now, eb_user_data_t user, eb_descriptor_callback_t ready);
    
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
    status_t flush();
    
    const Socket socket() const;
    Socket socket();
    
    width_t width() const;
    
  protected:
    Device(eb_device_t device);
    eb_device_t device;
  
  friend class Cycle;
  template <typename T, void (T::*cb)(Operation, Device, status_t)>
  friend void proxy_cb(T* object, eb_device_t dev, eb_operation_t op, eb_status_t status);
};

class Cycle {
  public:
    Cycle();
    
    // Start a cycle on the target device.
    template <typename T>
    status_t open(Device device, T* user, void (*cb)(T*, eb_device_t, eb_operation_t, eb_status_t));
    status_t open(Device device);
    
    void abort();
    void close();
    void close_silently();
    
    void read (address_t address, format_t format = EB_DATAX, data_t* data = 0);
    void write(address_t address, format_t format, data_t  data);
    
    void read_config (address_t address, format_t format = EB_DATAX, data_t* data = 0);
    void write_config(address_t address, format_t format, data_t  data);
    
    const Device device() const;
    Device device();
    
  protected:
    Cycle(eb_cycle_t cycle);
    eb_cycle_t cycle;
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
    format_t  format () const;
    
    const Operation next() const;
    Operation next();
    
  protected:
    Operation(eb_operation_t op);
    
    eb_operation_t operation;

  template <typename T, void (T::*cb)(Operation, Device, status_t)>
  friend void proxy_cb(T* object, eb_device_t dev, eb_operation_t op, eb_status_t status);
};

/* Convenience templates to convert member functions into callback type */
template <typename T, void (T::*cb)(Operation, Device, status_t)>
inline void proxy_cb(T* object, eb_device_t dev, eb_operation_t op, eb_status_t status) {
  return (object->*cb)(Operation(op), Device(dev), status);
}

/****************************************************************************/
/*                            C++ Implementation                            */
/****************************************************************************/

/* Proxy functions needed by C++ -- ignore these */
EB_PUBLIC eb_status_t eb_proxy_read_handler(eb_user_data_t data, eb_address_t address, eb_width_t width, eb_data_t* ptr);
EB_PUBLIC eb_status_t eb_proxy_write_handler(eb_user_data_t data, eb_address_t address, eb_width_t width, eb_data_t value);

inline Socket::Socket(eb_socket_t sock)
 : socket(sock) { 
}

inline Socket::Socket()
 : socket(EB_NULL) {
}

inline status_t Socket::open(const char* port, width_t width) {
  return eb_socket_open(EB_ABI_CODE, port, width, &socket);
}

inline status_t Socket::close() {
  status_t out = eb_socket_close(socket);
  if (out == EB_OK) socket = EB_NULL;
  return out;
}

inline status_t Socket::attach(sdwb_device_t device, Handler* handler) {
  struct eb_handler h;
  h.device = device;
  h.data = handler;
  h.read  = &eb_proxy_read_handler;
  h.write = &eb_proxy_write_handler;
  return eb_socket_attach(socket, &h);
}

inline status_t Socket::detach(sdwb_device_t device) {
  return eb_socket_detach(socket, device);
}

inline int Socket::run(int timeout_us) {
  return eb_socket_run(socket, timeout_us);
}

inline uint32_t Socket::timeout() const {
  return eb_socket_timeout(socket);
}

inline void Socket::descriptors(eb_user_data_t user, eb_descriptor_callback_t list) const {
  return eb_socket_descriptors(socket, user, list);
}

inline void Socket::check(uint32_t now, eb_user_data_t user, eb_descriptor_callback_t ready) {
  return eb_socket_check(socket, now, user, ready);
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

inline status_t Device::flush() {
  return eb_device_flush(device);
}

inline Cycle::Cycle()
 : cycle(EB_NULL) {
}

template <typename T>
inline eb_status_t Cycle::open(Device device, T* user, void (*cb)(T*, eb_device_t, eb_operation_t, status_t)) {
  return eb_cycle_open(device.device, user, reinterpret_cast<eb_callback_t>(cb), &cycle);
}

inline eb_status_t Cycle::open(Device device) {
  return eb_cycle_open(device.device, 0, 0, &cycle);
}

inline void Cycle::abort() {
  eb_cycle_abort(cycle);
  cycle = EB_NULL;
}

inline void Cycle::close() {
  eb_cycle_close(cycle);
  cycle = EB_NULL;
}

inline void Cycle::close_silently() {
  eb_cycle_close_silently(cycle);
  cycle = EB_NULL;
}

void Cycle::read(address_t address, format_t format, data_t* data) {
  eb_cycle_read(cycle, address, format, data);
}

void Cycle::write(address_t address, format_t format, data_t data) {
  eb_cycle_write(cycle, address, format, data);
}

void Cycle::read_config(address_t address, format_t format, data_t* data) {
  eb_cycle_read_config(cycle, address, format, data);
}

void Cycle::write_config(address_t address, format_t format, data_t data) {
  eb_cycle_write_config(cycle, address, format, data);
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

inline format_t Operation::format() const {
  return eb_operation_format(operation);
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
