/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory using C malloc.
 */

#ifdef EB_USE_MALLOC

#include <stdlib.h>
#include "memory.h"

eb_cycle_operation_t eb_new_cycle_operation(void) {
  return (eb_cycle_operation_t)malloc(sizeof(struct eb_cycle_operation));
}

eb_cycle_t eb_new_cycle(void) {
  return (eb_cycle_t)malloc(sizeof(struct eb_cycle));
}

void eb_free_cycle_operation(eb_cycle_operation_t x) {
  free(x);
}

void eb_free_cycle(eb_cycle_t x) {
  free(x);
}

#endif
