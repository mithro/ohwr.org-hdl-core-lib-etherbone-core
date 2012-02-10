#ifndef RING_H
#define RING_H

#include "../etherbone.h"

typedef struct eb_ring {
  struct eb_ring* prev;
  struct eb_ring* next;
} *eb_ring_t;

EB_PRIVATE void eb_ring_init(eb_ring_t r);
EB_PRIVATE void eb_ring_destroy(eb_ring_t r);

EB_PRIVATE void eb_ring_splice(eb_ring_t a, eb_ring_t b);
EB_PRIVATE void eb_ring_remove(eb_ring_t r);

#endif
