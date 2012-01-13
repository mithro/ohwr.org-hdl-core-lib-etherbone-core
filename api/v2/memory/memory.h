/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory management.
 */

#ifndef EB_MEMORY_H
#define EB_MEMORY_H

#include "../etherbone.h"
#include "../cycle/cycle.h"
#include "../device/device.h"
#include "../socket/socket.h"

#include "memory-malloc.h"
#include "memory-array.h"

/* These return EB_NULL on out-of-memory */
eb_cycle_operation_t eb_new_cycle_operation(void);
eb_cycle_t eb_new_cycle(void);
eb_device_t eb_new_device(void);
eb_handler_callback_t eb_new_handler_callback(void);
eb_handler_address_t eb_new_handler_address(void);
eb_response_t eb_new_response(void);
eb_socket_t eb_new_socket(void);

void eb_free_cycle_operation(eb_cycle_operation_t x);
void eb_free_cycle(eb_cycle_t x);
void eb_free_device(eb_device_t x);
void eb_free_handler_callback(eb_handler_callback_t x);
void eb_free_handler_address(eb_handler_address_t x);
void eb_free_response(eb_response_t x);
void eb_free_socket(eb_socket_t x);

#endif
