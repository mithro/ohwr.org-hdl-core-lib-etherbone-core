/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone cycle data structure.
 */

#ifndef EB_CYCLE_H
#define EB_CYCLE_H

#include "../etherbone.h"

struct eb_cycle {
  eb_callback_t callback;
  eb_user_data_t user_data;
  
  eb_operation_t first; /* if points to cycle, means OOM */
  union {
    eb_cycle_t next;
    eb_device_t device;
  };
};

/* Recursively free the operations. Does not free cycle. */
void eb_cycle_destroy(eb_cycle_t cycle);

#endif
