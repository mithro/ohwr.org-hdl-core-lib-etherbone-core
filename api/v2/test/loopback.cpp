/** @file loopback.cpp
 *  @brief A test program which executes many many EB queries.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  All Etherbone object types are opaque in this interface.
 *  Only those methods listed in this header comprise the public interface.
 *
 *  @author Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 *  @bug None!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */

#define __STDC_FORMAT_MACROS

#include <stdio.h>
#include <stdlib.h>

#include <vector>
#include <queue>
#include <algorithm>

#include "../etherbone.h"

using namespace etherbone;
using namespace std;

void die(const char* why, status_t error);
address_t hash(address_t address);
void test_query(Device device, int len, int requests);
void test_width(Socket socket, width_t width);

static int serial = 0;
static bool loud = false;

void die(const char* why, status_t error) {
  fflush(stdout);
  fprintf(stderr, "%s: %s (%d)\n", why, eb_status(error), serial);
  exit(1);
}

address_t hash(address_t address) {
  return ~address;
}

enum RecordType { READ_BUS, READ_CFG, WRITE_BUS, WRITE_CFG };
struct Record {
  address_t address;
  data_t data;
  bool error;
  RecordType type;
  
  Record();
};

Record::Record() 
 : address(random()),
   data(random()) {
  long seed = random();
  
  address = (address << 1) | (seed&1);
  seed >>= 1;
  data = (data << 1) | (seed&1);
  seed >>= 1;
  // !!! make it likely to do fifo/seq
  
  switch (seed & 3) {
  case 0: type = READ_BUS; break;
  case 1: type = READ_CFG; break;
  case 2: type = WRITE_BUS; break;
  case 3: type = WRITE_CFG; break;
  }
  seed >>= 2;
  
  if (type == READ_CFG)
    data = 0;
  if (type == READ_BUS)
    data = hash(address);
  
  if (type == READ_CFG || type == WRITE_CFG) {
    /* Config space is narrower */
    address &= 0x7FFF;
    /* Don't stomp on the error flag register */
    if (address < 8) address = 8;
    error = 0;
  } else {
    error = (address & 3) == 1;
  }
}

queue<Record> expect;
class Echo : public Handler {
public:
  status_t read (address_t address, width_t width, data_t* data);
  status_t write(address_t address, width_t width, data_t  data);
};

status_t Echo::read (address_t address, width_t width, data_t* data) {
  if (loud)
    printf("recvd read  to %016"EB_ADDR_FMT"(bus): ", address);

  if (expect.empty()) die("unexpected read", EB_FAIL);
  Record r = expect.front();
  expect.pop();
  
  /* Confirm it's as we expect */
  if (r.type != READ_BUS) die("wrong op recvd", EB_FAIL);
  if (r.address != address) die("wrong addr recvd", EB_FAIL);
  
  *data = r.data;
  
  if (loud)
    printf("%016"EB_DATA_FMT": %s\n", *data, r.error?"fault":"ok");

  return r.error?EB_FAIL:EB_OK;
}

status_t Echo::write(address_t address, width_t width, data_t  data) {
  if (loud)
    printf("recvd write to %016"EB_ADDR_FMT"(bus): %016"EB_DATA_FMT": ", address, data);

  if (expect.empty()) die("unexpected write", EB_FAIL);
  Record r = expect.front();
  expect.pop();
  
  /* Confirm it's as we expect */
  if (r.type != WRITE_BUS) die("wrong op recvd", EB_FAIL);
  if (r.address != address) die("wrong addr recvd", EB_FAIL);
  if (r.data != data) die("wrong data recvd", EB_FAIL);
  
  if (loud)
    printf("%s\n", r.error?"fault":"ok");
  
  return r.error?EB_FAIL:EB_OK;
}

class TestCycle {
public:
  std::vector<Record> records;
  int* success;

  void launch(Device device, int length, int* success);
  void complete(Operation op, status_t status);
};

void TestCycle::complete(Operation op, status_t status) {
  if (status != EB_OK) die("cycle failed", status);

  for (unsigned i = 0; i < records.size(); ++i) {
    Record& r = records[i];
    
    if (op.is_null()) die("unexpected null op", EB_FAIL);
    
    if (loud)
      printf("reply %s to %016"EB_ADDR_FMT"(%s): %016"EB_DATA_FMT": %s\n", 
        op.is_read() ? "read ":"write",
        op.address(),
        op.is_config() ? "cfg" : "bus",
        op.data(),
        op.had_error()?"fault":"ok");
    
    switch (r.type) {
    case READ_BUS:  if (!op.is_read() ||  op.is_config()) die("wrong op", EB_FAIL); break;
    case READ_CFG:  if (!op.is_read() || !op.is_config()) die("wrong op", EB_FAIL); break;
    case WRITE_BUS: if ( op.is_read() ||  op.is_config()) die("wrong op", EB_FAIL); break;
    case WRITE_CFG: if ( op.is_read() || !op.is_config()) die("wrong op", EB_FAIL); break;
    }
    
    if (op.address  () != r.address) die("wrong addr", EB_FAIL);
    if (op.data     () != r.data)    die("wrong data", EB_FAIL);
    if (op.had_error() != r.error)   die("wrong flag", EB_FAIL);
    
    op = op.next();
  }
  if (!op.is_null()) die("too many ops", EB_FAIL);
  
  ++*success;
}

void TestCycle::launch(Device device, int length, int* success_) {
  success = success_;
  
  Cycle cycle(device, this, &proxy<TestCycle, &TestCycle::complete>);
  
  for (int op = 0; op < length; ++op) {
    Record r;
    switch (r.type) {
    case READ_BUS:  cycle.read        (r.address, 0);      break;
    case READ_CFG:  cycle.read_config (r.address, 0);      break;
    case WRITE_BUS: cycle.write       (r.address, r.data); break;
    case WRITE_CFG: cycle.write_config(r.address, r.data); break;
    }
    records.push_back(r);
    
    if (r.type == READ_BUS || r.type == WRITE_BUS)
      expect.push(r);

    if (loud)
      printf("query %s to %016"EB_ADDR_FMT"(%s): %016"EB_DATA_FMT"\n", 
        (r.type == READ_BUS || r.type == READ_CFG) ? "read ":"write",
        r.address,
        (r.type == READ_CFG || r.type == WRITE_CFG) ? "cfg" : "bus",
        r.data);
  }
}

void test_query(Device device, int len, int requests) {
  std::vector<int> cuts;
  std::vector<TestCycle> tests;
  unsigned i;
  int success, timeout;
  ++serial;
  
/*
  if (serial == 166431) {
    printf("Enabling debug\n");
    loud = true;
  }
*/
  
  cuts.push_back(0);
  cuts.push_back(len);
  for (int cut = 1; cut < requests; ++cut)
    cuts.push_back(len ? (random() % (len+1)) : 0);
  sort(cuts.begin(), cuts.end());
  
  /* Prepare each cycle */
  tests.resize(requests);
  success = 0;
  for (i = 1; i < cuts.size(); ++i) {
    int amount = cuts[i] - cuts[i-1];
    tests[i-1].launch(device, amount, &success);
    if (loud) {
      if (i == cuts.size()-1) printf("---\n"); 
      else printf("...\n");
    }
  }
  
  /* Flush the queries */
  device.flush();
  
  /* Wait until all complete successfully */
  timeout = 1000000; /* 1 second */
  Socket socket = device.socket();
  while (success < requests && timeout > 0) {
    timeout -= socket.block(timeout);
    socket.poll();
  }
  
  if (timeout < 0) die("waiting for loopback success", EB_TIMEOUT);
}

void test_width(Socket socket, width_t width) {
  Device device;
  status_t err;
  
  if ((err = device.open(socket, "udp/localhost/8183", width)) != EB_OK) die("device.open", err);
  
  for (int len = 0; len < 4000; ++len)
    for (int requests = 1; requests <= 9; ++requests)
      for (int repetitions = 0; repetitions < 100; ++repetitions)
        test_query(device, len, requests);
    
  if ((err = device.close()) != EB_OK) die("device.close", err);
}  

int main() {
  status_t err;
  
  Socket socket;
  if ((err = socket.open(8183)) != EB_OK) die("socket.open", err);
  
  Echo echo;
  if ((err = socket.attach(0, ~0, &echo)) != EB_OK) die("socket.attach", err);
  
  /* for widths */
  test_width(socket, EB_DATAX | EB_ADDRX);
  return 0;
}
