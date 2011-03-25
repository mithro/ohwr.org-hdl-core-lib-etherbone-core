#include <stdlib.h>
#include <assert.h>
#include "queue.h"

void eb_queue_init(eb_queue_t q) {
  q->size = 0;
  q->reserved = 16;
  q->buf = (uint64_t*)malloc(sizeof(uint64_t)*q->reserved);
  assert (q->buf != 0);
}

void eb_queue_destroy(eb_queue_t q) {
  q->size = 0;
  q->reserved = 0;
  free(q->buf);
}

void eb_queue_push(eb_queue_t q, uint64_t value) {
  if (q->size == q->reserved) {
    q->reserved *= 2;
    q->buf = realloc(q->buf, sizeof(uint64_t)*q->reserved);
  }
  
  q->buf[q->size] = value;
  ++q->size;
}

void eb_queue_clear(eb_queue_t q) {
  q->size = 0;
}
