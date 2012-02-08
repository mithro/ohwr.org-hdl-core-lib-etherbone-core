/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements the Etherbone cycle data structure.
 */

#include "../etherbone.h"

using namespace etherbone;

static void eb_descriptor_push(eb_user_data_t data, eb_descriptor_t des) {
  std::vector<descriptor_t>* out = (std::vector<descriptor_t>*)data;
  out->push_back(des);
}

std::vector<descriptor_t> Socket::descriptor() const {
  std::vector<descriptor_t> out;
  eb_socket_descriptor(socket, &out, &eb_descriptor_push);
  return out;
}
