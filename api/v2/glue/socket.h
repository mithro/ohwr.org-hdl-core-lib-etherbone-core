/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone socket data structure.
 */

#ifndef EB_SOCKET_H
#define EB_SOCKET_H

#include "../etherbone.h"
#include "../transport/transport.h"

typedef EB_POINTER(eb_handler_callback) eb_handler_callback_t;
struct eb_handler_callback {
  eb_user_data_t data;
  
  eb_status_t (*read) (eb_user_data_t, eb_address_t, eb_width_t, eb_data_t*);
  eb_status_t (*write)(eb_user_data_t, eb_address_t, eb_width_t, eb_data_t);
};

typedef EB_POINTER(eb_handler_address) eb_handler_address_t;
struct eb_handler_address {
  eb_address_t base;
  eb_address_t mask;
  eb_handler_callback_t callback;
  eb_handler_address_t next;
};

typedef EB_POINTER(eb_response) eb_response_t;
struct eb_response {
  /* HxxxxxxxxxxxxxxL
   * H=0 means probe
   * H=1 L=0 means read-back
   * H=1 L=1 means status-back
   */
  uint16_t cfg_address;
  uint16_t deadline; /* Low 16-bits of a UTC seconds counter */
  
  eb_response_t next;
  
  union {
    eb_cycle_t cycle;
    eb_device_t device;
  };
  
  eb_operation_t write_cursor;
  eb_operation_t status_cursor;
};

struct eb_socket {
  eb_device_t first_device;
  eb_handler_address_t first_handler;
  
  /* Functional-style queue using lists */
  eb_response_t first_response;
  eb_response_t last_response;
  
  eb_transport_t first_transport;
  uint8_t widths;
};

eb_response_t eb_socket_flip_last(eb_socket_t socket);

#endif
