#ifndef QUEUE_H
#define QUEUE_H

#include "../etherbone.h"
#include <stdint.h>

typedef struct eb_queue {
  uint64_t* buf;
  unsigned int size;
  unsigned int reserved;
} *eb_queue_t;

EB_PRIVATE void eb_queue_init(eb_queue_t q);
EB_PRIVATE void eb_queue_destroy(eb_queue_t q);

EB_PRIVATE void eb_queue_push(eb_queue_t q, uint64_t value);
EB_PRIVATE void eb_queue_clear(eb_queue_t q);

#endif
