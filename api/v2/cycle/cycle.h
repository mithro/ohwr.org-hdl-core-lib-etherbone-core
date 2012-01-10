#ifndef _EB_CYCLE_H_
#define _EB_CYCLE_H_

#include "../etherbone.h"

typedef uint8_t eb_cycle_operation_flags_t;
#define EB_OP_WRITE 1
#define EB_OP_READ 0
#define EB_OP_CFG_SPACE 2
#define EB_OP_BUS_SPACE 0

struct eb_cycle_operation {
  eb_address_t address;
  union {
    eb_data_t  write_value;
    eb_data_t* read_destination;
  };
  eb_cycle_operation_flags_t flags;
  EB_POINTER(eb_cycle_operation) next;
};
typedef EB_POINTER(eb_cycle_operation) eb_cycle_operation_t;

typedef uint8_t eb_cycle_flags_t;
#define EB_CYCLE_CHECK 1
#define EB_CYCLE_QUIET 0

struct eb_cycle {
  eb_device_t device;
  
  eb_callback_t callback;
  eb_user_data_t user_data;
  
  eb_cycle_operation_t first;
  eb_cycle_flags_t flags;
};

#endif
