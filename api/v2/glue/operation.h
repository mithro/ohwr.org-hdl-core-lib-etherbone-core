/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone operation data structure.
 */

#ifndef EB_OPERATION_H
#define EB_OPERATION_H

#include "../etherbone.h"

typedef uint8_t eb_cycle_operation_flags_t;
#define EB_OP_WRITE	0x00
#define EB_OP_READ_PTR	0x01
#define EB_OP_READ_VAL	0x02
#define EB_OP_MASK      0x03

#define EB_OP_CFG_SPACE	0x04
#define EB_OP_BUS_SPACE	0x00
#define EB_OP_ERROR	0x08
#define EB_OP_OK	0x00
#define EB_OP_CHECKED	0x10
#define EB_OP_SILENT	0x00

typedef EB_POINTER(eb_cycle_operation) eb_cycle_operation_t;
struct eb_operation {
  eb_address_t address;
  union {
    eb_data_t  write_value;
    eb_data_t  read_value;
    eb_data_t* read_destination;
  };
  
  eb_cycle_operation_flags_t flags;
  eb_cycle_operation_t next;
};

#endif
