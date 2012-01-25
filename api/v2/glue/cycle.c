/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone cycle data structure.
 */

#include "operation.h"
#include "cycle.h"
#include "device.h"
#include "../memory/memory.h"

eb_device_t eb_cycle_device(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  
  cycle = EB_CYCLE(cyclep);
  return cycle->device;
}

eb_cycle_t eb_cycle_open(eb_device_t devicep, eb_user_data_t user, eb_callback_t cb) {
  eb_cycle_t cyclep;
  struct eb_cycle* cycle;
  struct eb_device* device;
  
  cyclep = eb_new_cycle();
  if (cyclep == EB_NULL)
    return cyclep;
  
  cycle = EB_CYCLE(cyclep);
  cycle->callback = cb;
  cycle->user_data = user;
  cycle->first = EB_NULL;
  cycle->device = devicep;
  
  device = EB_DEVICE(devicep);
  ++device->unready;
  
  return cyclep;
}

void eb_cycle_destroy(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  eb_operation_t i, next;
  
  cycle = EB_CYCLE(cyclep);
  
  if (cycle->dead != cyclep) {
    for (i = cycle->first; i != EB_NULL; i = next) {
      next = EB_OPERATION(i)->next;
      eb_free_operation(i);
    }
  }
  
  cycle->first = EB_NULL;
}

void eb_cycle_abort(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  struct eb_device* device;
  
  cycle = EB_CYCLE(cyclep);
  device = EB_DEVICE(cycle->device);
  --device->unready;
  
  eb_cycle_destroy(cyclep);
  eb_free_cycle(cyclep);
}

void eb_cycle_close_silently(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  struct eb_operation* op;
  struct eb_device* device;
  eb_operation_t prev, i, next;
  
  cycle = EB_CYCLE(cyclep);
  device = EB_DEVICE(cycle->device);

  /* Reverse the linked-list so it's FIFO */
  if (cycle->dead != cyclep) {
    prev = EB_NULL;
    for (i = cycle->first; i != EB_NULL; i = next) {
      op = EB_OPERATION(i);
      next = op->next;
      op->next = prev;
      prev = i;
    }
    cycle->first = prev;
  }
  
  /* Queue us to the device */
  cycle->next = device->ready;
  device->ready = cyclep;
  
  /* Remove us from the incomplete cycle counter */
  --device->unready;
}

void eb_cycle_close(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  struct eb_operation* op;
  eb_operation_t opp;
  
  eb_cycle_close_silently(cyclep);
  
  cycle = EB_CYCLE(cyclep);
  opp = cycle->first;
  
  if (opp != EB_NULL && cycle->dead != cyclep) {
    op = EB_OPERATION(opp);
    op->flags |= EB_OP_CHECKED;
  }
}

static struct eb_operation* eb_cycle_doop(eb_cycle_t cyclep) {
  eb_operation_t opp;
  struct eb_cycle* cycle;
  struct eb_operation* op;
  static struct eb_operation crap;
  
  cycle = EB_CYCLE(cyclep);
  
  if (cycle->dead == cyclep) {
    /* Already ran OOM on this cycle */
    return &crap;
  }
  
  opp = eb_new_operation();
  if (opp == EB_NULL) {
    /* Record out-of-memory with a self-pointer */
    eb_cycle_destroy(cyclep);
    cycle->dead = cyclep;
    return &crap;
  }
  
  op = EB_OPERATION(opp);
  
  op->next = cycle->first;
  cycle->first = opp;
  return op;
}

void eb_cycle_read(eb_cycle_t cycle, eb_address_t address, eb_data_t* data) {
  struct eb_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->read_destination = data;
  
  if (data) op->flags = EB_OP_READ_PTR | EB_OP_BUS_SPACE;
  else      op->flags = EB_OP_READ_VAL | EB_OP_BUS_SPACE;
}

void eb_cycle_read_config(eb_cycle_t cycle, eb_address_t address, eb_data_t* data) {
  struct eb_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->read_destination = data;
  
  if (data) op->flags = EB_OP_READ_PTR | EB_OP_CFG_SPACE;
  else      op->flags = EB_OP_READ_VAL | EB_OP_CFG_SPACE;
}

void eb_cycle_write(eb_cycle_t cycle, eb_address_t address, eb_data_t data) {
  struct eb_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->write_value = data;
  op->flags = EB_OP_WRITE | EB_OP_BUS_SPACE;
}

void eb_cycle_write_config(eb_cycle_t cycle, eb_address_t address, eb_data_t data) {
  struct eb_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->write_value = data;
  op->flags = EB_OP_WRITE | EB_OP_CFG_SPACE;
}
