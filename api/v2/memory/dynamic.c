/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory using an internally managed array.
 * The array is dynamically managed using realloc.
 */

#if !defined(EB_USE_STATIC) && !defined(EB_USE_MALLOC)

#include <stdlib.h>
#include "memory.h"

union eb_memory_item* eb_memory_array = 0;
static EB_POINTER(eb_memory_item) eb_memory_array_size = 128; /* ie: initally 256 */

int eb_expand_array(void) {
  void* new_address;
  EB_POINTER(eb_memory_item) next_size, i;
  
  /* Doubling ensures constant cost */
  next_size = eb_memory_array_size + eb_memory_array_size;
  
  if (eb_memory_array)
    new_address = realloc(eb_memory_array, sizeof(union eb_memory_item) * next_size);
  else
    new_address = malloc(sizeof(union eb_memory_item) * next_size);
  
  if (new_address == 0) 
    return -1;
  
  eb_memory_array = (union eb_memory_item*)new_address;
  
  /* Link together the expanded free list */
  for (i = eb_memory_array_size; i != next_size; ++i)
    eb_memory_array[i].free_item.next = i+1; 
  
  eb_memory_array[next_size-1].free_item.next = EB_END_OF_FREE;
  eb_memory_array_free = eb_memory_array_size;
  eb_memory_array_size = next_size;
  
  return 0;
}

#endif
