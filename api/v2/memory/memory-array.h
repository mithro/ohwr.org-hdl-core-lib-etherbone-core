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
  struct eb_operation operation;
  struct eb_cycle cycle;
  struct eb_device device;
  struct eb_socket socket;
  struct eb_handler_callback handler_callback;
  struct eb_handler_address handler_address;
  struct eb_response response;
  struct eb_free_item free_item;
};

#define EB_END_OF_FREE EB_NULL

#ifdef EB_USE_STATIC
extern union eb_memory_item eb_memory_array[];
#else
extern union eb_memory_item* eb_memory_array;
#endif

extern EB_POINTER(eb_memory_item) eb_memory_free;
extern int eb_expand_array(void);

#define EB_OPERATION(x) (&eb_memory_array[x].operation)
#define EB_CYCLE(x) (&eb_memory_array[x].cycle)
#define EB_DEVICE(x) (&eb_memory_array[x].device)
#define EB_SOCKET(x) (&eb_memory_array[x].socket)
#define EB_HANDLER_CALLBACK(x) (&eb_memory_array[x].handler_callback)
#define EB_HANDLER_ADDRESS(x) (&eb_memory_array[x].handler_address)
#define EB_RESPONSE(x) (&eb_memory_array[x].response)
#define EB_FREE_ITEM(x) (&eb_memory_array[x].free_item)

#endif
#endif
