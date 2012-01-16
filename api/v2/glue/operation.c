/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone cycle data structure.
 */

#include "operation.h"
#include "../memory/memory.h"

eb_operation_t eb_operation_next(eb_operation_t opp) {
  return EB_OPERATION(opp)->next;
}

int eb_operation_is_read(eb_operation_t opp) {
  return (EB_OPERATION(opp)->flags & EB_OP_MASK) != EB_OP_WRITE;
}

int eb_operation_is_config(eb_operation_t opp) {
  return (EB_OPERATION(opp)->flags & EB_OP_CFG_SPACE) != 0;
}

int eb_operation_had_error(eb_operation_t opp) {
  return (EB_OPERATION(opp)->flags & EB_OP_ERROR) != 0;
}

eb_address_t eb_operation_address(eb_operation_t opp) {
  return EB_OPERATION(opp)->address;
}

eb_data_t eb_operation_data(eb_operation_t opp) {
  struct eb_operation* op;
  
  op = EB_OPERATION(opp);
  switch (op->flags & EB_OP_MASK) {
  case EB_OP_WRITE:	return op->write_value;
  case EB_OP_READ_PTR:	return *op->read_destination;
  case EB_OP_READ_VAL:	return op->read_value;
  }
  
  /* unreachable */
  return 0;
}
