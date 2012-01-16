/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory using an internally managed array.
 * The array can be either staticly sized or dynamically managed.
 */

#include <stdio.h>

#include "../memory/memory.h"

int main(void) {
  printf("operation        = %lu\n", (unsigned long)sizeof(struct eb_operation));
  printf("cycle            = %lu\n", (unsigned long)sizeof(struct eb_cycle));
  printf("device           = %lu\n", (unsigned long)sizeof(struct eb_device));
  printf("socket           = %lu\n", (unsigned long)sizeof(struct eb_socket));
  printf("handler_callback = %lu\n", (unsigned long)sizeof(struct eb_handler_callback));
  printf("handler_address  = %lu\n", (unsigned long)sizeof(struct eb_handler_address));
  printf("response         = %lu\n", (unsigned long)sizeof(struct eb_response));
  printf("free_item        = %lu\n", (unsigned long)sizeof(struct eb_free_item));
  printf("union            = %lu\n", (unsigned long)sizeof(union eb_memory_item));
  return 0;
}
