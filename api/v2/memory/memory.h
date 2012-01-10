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

#include "memory-malloc.h"
#include "memory-array.h"

/* These return EB_NULL on out-of-memory */
eb_cycle_operation_t eb_new_cycle_operation(void);
eb_cycle_t eb_new_cycle(void);

void eb_free_cycle_operation(eb_cycle_operation_t x);
void eb_free_cycle(eb_cycle_t x);

#endif
