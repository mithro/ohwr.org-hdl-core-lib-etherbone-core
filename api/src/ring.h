#ifndef RING_H
#define RING_H

typedef struct eb_ring {
  struct eb_ring* prev;
  struct eb_ring* next;
} *eb_ring_t;

void eb_ring_init(eb_ring_t r);
void eb_ring_splice(eb_ring_t a, eb_ring_t b);
void eb_ring_remove(eb_ring_t r);

#endif
