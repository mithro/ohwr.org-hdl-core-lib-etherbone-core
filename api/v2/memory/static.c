/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory using an internally managed array.
 * The array is staticly allocated and constant sized.
 */

#ifdef EB_USE_STATIC

#include "memory.h"

union eb_memory_item eb_memory_array[EB_USE_STATIC];
static const EB_POINTER(eb_memory_item) eb_memory_array_size = EB_USE_STATIC;

int eb_expand_array(void) {
  static int setup = 0;
  EB_POINTER(eb_memory_item) i;
  
  if (!setup) {
    setup = 1;
    
    for (i = 0; i != eb_memory_array_size; ++i)
      EB_FREE_ITEM(i)->next = i+1;
    
    EB_FREE_ITEM(eb_memory_array_size-1)->next = EB_END_OF_FREE;
    eb_memory_free = 0;
    
    return 0;
  } else {
    return -1;
  }
}

#endif
