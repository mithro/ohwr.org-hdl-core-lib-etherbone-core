#include "ring.h"

void eb_ring_init(eb_ring_t r) {
  r->prev = r;
  r->next = r;
}

void eb_ring_remove(eb_ring_t r) {
  r->prev->next = r->next;
  r->next->prev = r->prev;
  r->next = r;
  r->prev = r;
}

void eb_ring_splice(eb_ring_t a, eb_ring_t b) {
  a->next->prev = b->prev;
  b->prev->next = a->next;
  a->next = b;
  b->prev = a;
}
