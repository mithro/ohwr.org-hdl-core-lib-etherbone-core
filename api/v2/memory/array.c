/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory using an internally managed array.
 * The array can be either staticly sized or dynamically managed.
 */

#define ETHERBONE_IMPL

#ifndef EB_USE_MALLOC

#include "memory.h"

EB_POINTER(eb_memory_item) eb_memory_free = EB_END_OF_FREE;

static EB_POINTER(eb_new_memory_item) eb_new_memory_item(void) {
  EB_POINTER(eb_memory_item) alloc;
  
  if (eb_memory_free == EB_END_OF_FREE) {
    if (eb_expand_array() < 0)
      return EB_NULL;
  }
  
  alloc = eb_memory_free;
  eb_memory_free = EB_FREE_ITEM(alloc)->next;
  
  return alloc;
}

static void eb_free_memory_item(EB_POINTER(eb_memory_item) item) {
  EB_FREE_ITEM(item)->next = eb_memory_free;
  eb_memory_free = item;
}

eb_operation_t        eb_new_operation       (void) { return (eb_operation_t)       eb_new_memory_item(); }
eb_cycle_t            eb_new_cycle           (void) { return (eb_cycle_t)           eb_new_memory_item(); }
eb_device_t           eb_new_device          (void) { return (eb_device_t)          eb_new_memory_item(); }
eb_handler_callback_t eb_new_handler_callback(void) { return (eb_handler_callback_t)eb_new_memory_item(); }
eb_handler_address_t  eb_new_handler_address (void) { return (eb_handler_address_t) eb_new_memory_item(); }
eb_response_t         eb_new_response        (void) { return (eb_response_t)        eb_new_memory_item(); }
eb_socket_t           eb_new_socket          (void) { return (eb_socket_t)          eb_new_memory_item(); }
eb_transport_t        eb_new_transport       (void) { return (eb_transport_t)       eb_new_memory_item(); }
eb_link_t             eb_new_link            (void) { return (eb_link_t)            eb_new_memory_item(); }

void eb_free_operation       (eb_operation_t        x) { eb_free_memory_item(x); }
void eb_free_cycle           (eb_cycle_t            x) { eb_free_memory_item(x); }
void eb_free_device          (eb_device_t           x) { eb_free_memory_item(x); }
void eb_free_handler_callback(eb_handler_callback_t x) { eb_free_memory_item(x); }
void eb_free_handler_address (eb_handler_address_t  x) { eb_free_memory_item(x); }
void eb_free_response        (eb_response_t         x) { eb_free_memory_item(x); }
void eb_free_socket          (eb_socket_t           x) { eb_free_memory_item(x); }
void eb_free_transport       (eb_transport_t        x) { eb_free_memory_item(x); }
void eb_free_link            (eb_link_t             x) { eb_free_memory_item(x); }

#endif
