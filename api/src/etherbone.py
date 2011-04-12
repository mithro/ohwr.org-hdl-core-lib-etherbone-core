#!   /usr/bin/env   python
#    coding: utf8

# python bindings for the etherbone unix library
# 
# this is a preliminary version that gives access to the
# core C99 library API
# just import-tested, probably full of horrendous bugs, needs
# extensive testing given that opaque types and nested 
# structures are used all over the place and this is very
# error-prone with ctypes (and my limited knowledge thereof)
#
# next thing to add is a proper, pythonic interface with 
# Socket, Device and Cycle classes hiding all the horrendous
# passing back and forth of pointers to opaque structs

from ctypes import *
lib = CDLL('./libetherbone.so')

# typedefs and enums are translated into ctypes mainly
# for documentation purposes; using them does not make
# much sense otherwise

# configurable types
eb_address_t = c_ulonglong
eb_data_t = c_ulonglong

# control types
eb_network_address_t = c_char_p
eb_descriptor_t = c_int

# opaque structural types
# for the time being, we can get through by defining
# these as c_void_p; later on, structure definitions for
# eb_socket, eb_device and eb_cycle can be provided to build
# or split these from Python
eb_socket_t = c_void_p
eb_device_t = c_void_p
eb_cycle_t = c_void_p

# status codes
eb_status_t = c_int
(   EB_OK,
    EB_FAIL,
    EB_ABORT,
    EB_ADDRESS,
    EB_OVERFLOW,
    EB_BUSY ) = range(6)
# modes
eb_mode_t = c_int
EB_UNDEFINED = -1
EB_FIFO = 0
EB_LINEAR = 1

# bitmasks
eb_flags_t = c_uint
EB_UDP_MODE	= 	0
EB_FEC_MODE	= 	1

# widths
eb_width_t = c_uint
EB_DATA8	= 	1
EB_DATA16	= 	2
EB_DATA32	= 	4
EB_DATA64	= 	8
EB_DATAX	= 	0xf

# callback types
eb_user_data_t = c_void_p
eb_read_callback_t  = CFUNCTYPE(None, eb_user_data_t, eb_status_t, eb_data_t)
eb_cycle_callback_t = CFUNCTYPE(None, eb_user_data_t, eb_status_t, POINTER(eb_data_t))

# handler descriptor
eb_read_type  = CFUNCTYPE(eb_data_t, eb_user_data_t, eb_address_t, eb_width_t)
eb_write_type = CFUNCTYPE(None, eb_user_data_t, eb_address_t, eb_width_t, eb_data_t)
class eb_handler(Structure):
    _fields_ = [
        ('base',  eb_address_t),
        ('mask',  eb_address_t),
        ('data',  eb_user_data_t),
        ('read',  eb_read_type),
        ('write', eb_write_type), ]

eb_handler_t = POINTER(eb_handler)

#
# C99 API
#

def eb_socket_open(port, flags, socket):
    """
    Open an Etherbone socket for communicating with remote devices.
    The port parameter is optional; 0 lets the operating system choose.
    After opening the socket, poll must be hooked into an event loop.

    Return codes:
      OK	- successfully open the socket port
      FAIL	- operating system forbids access
      BUSY	- specified port is in use (only possible if port != 0)
    """
    return lib.eb_socket_open(port, flags, socket)


def eb_socket_close(socket):
    """
    Close the Etherbone socket.
    Any use of the socket after successful close will probably segfault!

    Return codes:
      OK		- successfully closed the socket and freed memory
      BUSY	- there are open devices on this socket
    """
    return lib.eb_socket_close(socket)


def eb_socket_poll(socket):
    """
    Poll the Etherbone socket for activity.
    This function must be called regularly to receive incoming packets.
    Either call poll very often or hook a read listener on its descriptor.
    Callback functions are only executed from within the poll function.

    Return codes:
      OK		- poll complete; no further packets to process
      FAIL       - socket error (probably closed)
    """
    return lib.eb_socket_poll(socket)

def eb_socket_block(socket, timeout_us):
    """
    Block until the socket is ready to be polled.
    This function is useful if your program has no event loop of its own.
    It returns the time spent while waiting.
    """
    return lib.eb_socket_block(socket, timeout_us)

def eb_socket_descriptor(socket):
    """
    Access the underlying file descriptor of the Etherbone socket.
    THIS MUST NEVER BE READ, WRITTEN, CLOSED, OR MODIFIED IN ANY WAY!
    It may be used to watch for read readiness to call poll.
    
    """
    return eb_socket_descriptor(socket)

def eb_socket_attach(socket, handler):
    """
    Add a device to the virtual bus.
    This handler receives all reads and writes to the specified address.
    NOTE: the address range [0x0, 0x7fff) is reserved for internal use.
    
    Return codes:
      OK         - the handler has been installed
      FAIL       - out of memory
      ADDRESS    - the specified address range overlaps an existing device.
    """
    return lib.eb_socket_attach(socket, handler)

def eb_socket_detach(socket, address):
    """
    Detach the device from the virtual bus.
    
    Return codes:
      OK         - the devices has be removed
      FAIL       - there is no device at the specified address.
    
    """
    return lib.eb_socket_detach(socket, address)

class Socket(object):
    """pythonically mimic C++ interface, to be done"""
    pass

def eb_device_open(socket, ip_port, proposed_widths, result):
    """
    Open a remote Etherbone device.
    This resolves the address and performs Etherbone end-point discovery.
    From the mask of proposed bus widths, one will be selected.
    The default port is taken as 0xEBD0.
    
    Return codes:
      OK		- the remote etherbone device is ready
      FAIL	- the remote address did not identify itself as etherbone conformant
      ADDRESS	- the network address could not be parsed
      ABORT      - could not negotiate an acceptable data bus width
    
    """
    return lib.eb_device_open(socket, ip_port, proposed_widths, result)


def eb_device_width(device):
    """
    Recover the negotiated data width of the target device.
    """
    return lib.eb_device_width(device)

def eb_device_close(device):
    """
    Close a remote Etherbone device.
    
    Return codes:
      OK    - associated memory has been freed
      BUSY	- there are outstanding wishbone cycles on this device
    """
    return lib.eb_device_close(device)

def eb_device_socket(device):
    """Access the socket backing this device
    """
    return lib.eb_device_socket(device)

def eb_device_flush(socket):
    """
    Flush commands queued on the device out the socket.
    """
    return lib.eb_device_flush(socket)

def eb_cycle_open_read_only(device, userdata, cycle_callback):
    """
    Begin a wishbone cycle on the remote device.
    Read/write phases within a cycle hold the device locked.
    All reads are executed first followed by all writes.
    Until the cycle is closed, the operations are not queued.
    
    If data was read, the callback is run upon cycle completion.
    
    Status codes:
      OK		- the operation completed successfully
      FAIL	- the operation failed due to an wishbone ERR_O signal
      ABORT	- an earlier operation failed and this operation was thus aborted
      OVERFLOW	- too many operations queued for this cycle
    """
    return lib.eb_cycle_open_read_only(device, userdata, cycle_callback)

def eb_cycle_open_read_write(device, user, cb, write_base, write_mode):
    """
    Begin a wishbone cycle on the remote device.
    Read/write phases within a cycle hold the device locked.
    All reads are executed first followed by all writes.
    Until the cycle is closed, the operations are not queued.
    
    If data was read, the callback is run upon cycle completion.
    
    Status codes:
      OK		- the operation completed successfully
      FAIL	- the operation failed due to an wishbone ERR_O signal
      ABORT	- an earlier operation failed and this operation was thus aborted
      OVERFLOW	- too many operations queued for this cycle
    """
    return lib.eb_cycle_open_read_write(device, user, cb, write_base, write_mode)

def eb_cycle_close(cycle):
    """
    End a wishbone cycle.
    This places the complete cycle at end of the device''s send queue.
    You will probably want to eb_flush_device soon after calling eb_cycle_close.
    
    """
    return lib.eb_cycle_close(cycle)

def eb_cycle_device(cycle):
    """Access the device targetted by this cycle
    """
    return eb_cycle_device(cycle)

def eb_cycle_read(cycle, address):
    """
    Prepare a wishbone read phase.
    The given address is read from the remote device.
    Upon return
    """
    return lib.eb_cycle_read(cycle, address)

def eb_cycle_write(cycle, data):
    """
    Perform a wishbone write phase.
    data is written to the current cursor on the remote device.
    If the device was read-only, the operation is discarded.
    """
    return lib.eb_cycle_write(cycle, data)

def eb_device_read(device, address, userdata, cb):

    """
    Perform a single-read wishbone cycle.
    Semantically equivalent to cycle_open, cycle_read, cycle_close, device_flush.
    
    The given address is read on the remote device.
    The callback cb(user, status, data) is invoked with the result.
    The user parameter is passed through uninspected to the callback.
    
    Status codes:
      OK		- the operation completed successfully
      FAIL	- the operation failed due to an wishbone ERR_O signal
      ABORT	- an earlier operation failed and this operation was thus aborted
    """
    return lib.eb_device_read(device, address, userdata, cb)

def eb_device_write(device, address, data):
    """
    Perform a single-write wishbone cycle.
    Semantically equivalent to cycle_open, cycle_write, cycle_close, device_flush.
    
    data is written to the given address on the remote device.
    """
    return lib.eb_device_write(device, address, data)

"""
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

    status_t open(Socket socket, network_address_t address, width_t width);
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

inline status_t Device::open(Socket socket, network_address_t address, width_t width) {
  return eb_device_open(socket.socket, address, width, &device);
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
"""
