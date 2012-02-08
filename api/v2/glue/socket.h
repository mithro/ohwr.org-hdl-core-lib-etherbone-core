/** @file socket.h
 *  @brief The Etherbone socket data structure.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Etherbone sockets are composed of two halves: eb_socket and eb_socket_aux.
 *  This split was made so that every dynamically allocated object is roughly
 *  the same size, easing the internal memory management implementation.
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
  /* xxxxxxxxxxxxxxxL
   * H=1 L=0 means read-back
   * H=1 L=1 means status-back
   */
  uint16_t address;
  uint16_t deadline; /* Low 16-bits of a UTC seconds counter */
  
  eb_response_t next;
  eb_cycle_t cycle;
  
  eb_operation_t write_cursor;
  eb_operation_t status_cursor;
};

typedef EB_POINTER(eb_socket_aux) eb_socket_aux_t;
struct eb_socket_aux {
  uint32_t time_cache;
  uint16_t rba;
  
  eb_transport_t first_transport;
};

struct eb_socket {
  eb_device_t first_device;
  eb_handler_address_t first_handler;
  
  /* Functional-style queue using lists */
  eb_response_t first_response;
  eb_response_t last_response;
  
  eb_socket_aux_t aux;
  uint8_t widths;
};

/* Invert last_response, suitable for attaching to the end of first_response */
EB_PRIVATE eb_response_t eb_socket_flip_last(struct eb_socket* socket);

/* Process inbound read/write requests */
EB_PRIVATE eb_data_t eb_socket_read        (eb_socket_t socket, eb_width_t width, eb_address_t addr,                  uint64_t* error);
EB_PRIVATE void      eb_socket_write       (eb_socket_t socket, eb_width_t width, eb_address_t addr, eb_data_t value, uint64_t* error);
EB_PRIVATE eb_data_t eb_socket_read_config (eb_socket_t socket, eb_width_t width, eb_address_t addr,                  uint64_t  error);
EB_PRIVATE void      eb_socket_write_config(eb_socket_t socket, eb_width_t width, eb_address_t addr, eb_data_t value);

#endif
