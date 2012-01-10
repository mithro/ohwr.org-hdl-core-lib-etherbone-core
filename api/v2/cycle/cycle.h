/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone cycle data structure.
 */

#ifndef EB_CYCLE_H
#define EB_CYCLE_H

#include "../etherbone.h"

typedef uint8_t eb_cycle_operation_flags_t;
#define EB_OP_WRITE 1
#define EB_OP_READ 0
#define EB_OP_CFG_SPACE 2
#define EB_OP_BUS_SPACE 0
#define EB_CYCLE_CHECK 4
#define EB_CYCLE_QUIET 0

typedef EB_POINTER(eb_cycle_operation) eb_cycle_operation_t;
struct eb_cycle_operation {
  eb_address_t address;
  union {
    eb_data_t  write_value;
    eb_data_t* read_destination;
  };
  
  eb_cycle_operation_flags_t flags;
  eb_cycle_operation_t next;
};

typedef uint8_t eb_cycle_flags_t;

struct eb_cycle {
  eb_callback_t callback;
  eb_user_data_t user_data;
  
  eb_cycle_operation_t first;
  union {
    eb_cycle_t next;
    eb_device_t device;
  };
};

#endif
