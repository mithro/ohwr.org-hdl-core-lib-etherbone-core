/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone cycle data structure.
 */

#include "cycle.h"
#include "../device/device.h"
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

void eb_cycle_close(eb_cycle_t cyclep) {
  struct eb_cycle* cycle;
  struct eb_cycle_operation* op;
  struct eb_device* device;
  eb_cycle_operation_t prev, i, next;
  
  cycle = EB_CYCLE(cyclep);
  
  /* Reverse the linked-list so it's FIFO */
  prev = EB_NULL;
  for (i = cycle->first; i != EB_NULL; i = next) {
    op = EB_CYCLE_OPERATION(i);
    next = op->next;
    op->next = prev;
    prev = i;
  }
  cycle->first = prev;
  
  device = EB_DEVICE(cycle->device);
  --device->unready;
  cycle->next = device->ready;
  device->ready = cyclep;
}

static struct eb_cycle_operation* eb_cycle_doop(eb_cycle_t cyclep) {
  eb_cycle_operation_t opp;
  struct eb_cycle* cycle;
  struct eb_cycle_operation* op;
  
  opp = eb_new_cycle_operation();
  if (opp == EB_NULL) {
    // ...
  }
  
  cycle = EB_CYCLE(cyclep);
  op = EB_CYCLE_OPERATION(opp);
  
  op->next = cycle->first;
  cycle->first = opp;
  return op;
}

void eb_cycle_read(eb_cycle_t cycle, eb_address_t address, eb_data_t* data) {
  struct eb_cycle_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->read_destination = data;
  op->flags = EB_OP_READ | EB_OP_BUS_SPACE;
}

void eb_cycle_read_config(eb_cycle_t cycle, eb_address_t address, eb_data_t* data) {
  struct eb_cycle_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->read_destination = data;
  op->flags = EB_OP_READ | EB_OP_CFG_SPACE;
}

void eb_cycle_write(eb_cycle_t cycle, eb_address_t address, eb_data_t data) {
  struct eb_cycle_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->write_value = data;
  op->flags = EB_OP_WRITE | EB_OP_BUS_SPACE;
}

void eb_cycle_write_config(eb_cycle_t cycle, eb_address_t address, eb_data_t data) {
  struct eb_cycle_operation* op;
  
  op = eb_cycle_doop(cycle);
  op->address = address;
  op->write_value = data;
  op->flags = EB_OP_WRITE | EB_OP_CFG_SPACE;
}
