/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory using an internally managed array.
 * The array can be either staticly sized or dynamically managed.
 */

#ifndef EB_USE_MALLOC

#include "memory.h"

EB_POINTER(eb_memory_item) eb_memory_free = EB_END_OF_FREE;

static EB_POINTER(eb_new_memory_item) eb_new_memory_item(void) {
  EB_POINTER(eb_memory_item) alloc;
  
  if (eb_memory_array_free == EB_END_OF_FREE) {
    if (eb_expand_array() < 0)
      return EB_NULL;
  }
  
  alloc = eb_memory_array_free;
  eb_memory_array_free = EB_FREE_ITEM(alloc)->next;
  
  return alloc;
}

static void eb_free_memory_item(EB_POINTER(eb_memory_item) item) {
  EB_FREE_ITEM(item)->next = eb_memory_array_free;
  eb_memory_array_free = item;
}

cycle_operation_t eb_new_cycle_operation(void) {
  return (cycle_operation_t)eb_new_memory_item();
}

cycle_t eb_new_cycle(void) {
  return (cycle_t)eb_new_memory_item();
}

void eb_free_cycle_operation(cycle_operation_t x) {
  eb_free_memory_item(x);
}

void eb_free_cycle(cycle_t x) {
  eb_free_memory_item(x);
}

#endif
