/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory using an internally managed array.
 * The array can be either staticly sized or dynamically managed.
 */

#ifndef EB_MEMORY_ARRAY_H
#define EB_MEMORY_ARRAY_H
#ifndef EB_USE_MALLOC

struct eb_free_item {
  EB_POINTER(eb_free_item) next;
};

union eb_memory_item {
  struct eb_cycle_operation cycle_operation;
  struct eb_cycle cycle;
  struct eb_free_item free_item;
};

#define EB_END_OF_FREE -1

#ifdef EB_USE_STATIC
extern union eb_memory_item eb_memory_array[];
#else
extern union eb_memory_item* eb_memory_array;
#endif

extern EB_POINTER(eb_memory_item) eb_memory_array_free;
extern int eb_expand_array(void);

#define EB_CYCLE_OPERATION(x) (&eb_memory_array[x].cycle_operation)
#define EB_CYCLE(x) (&eb_memory_array[x].cycle)
#define EB_FREE_ITEM(x) (&eb_memory_array[x].free_item)

#define EB_NEW_FAILED EB_END_OF_FREE

#endif
#endif
