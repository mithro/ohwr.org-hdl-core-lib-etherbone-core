/** @file slave.c
 *  @brief Process (and reply to) an Etherbone request.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  Processing of read/write operations is deffered to glue/readwrite.c.
 *  Unlink a hardware implementation, responses to writes are not padded.
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

#define ETHERBONE_IMPL

#include <string.h>

#include "../transport/transport.h"
#include "../glue/socket.h"
#include "../glue/device.h"
#include "../glue/widths.h"
#include "../memory/memory.h"
#include "bigendian.h"
#include "format.h"

static inline eb_data_t EB_LOAD(uint8_t* rptr, int alignment) {
  switch (alignment) {
  case 2: return be16toh(*(uint16_t*)rptr);
  case 4: return be32toh(*(uint32_t*)rptr);
  case 8: return be64toh(*(uint64_t*)rptr);
  }
  return 0; /* unreachable */
}

static inline void EB_sWRITE(uint8_t* wptr, eb_data_t val, int alignment) {
  switch (alignment) {
  case 2: *(uint16_t*)wptr = htobe16(val); break;
  case 4: *(uint32_t*)wptr = htobe32(val); break;
  case 8: *(uint64_t*)wptr = htobe64(val); break;
  }
}

void eb_device_slave(eb_socket_t socketp, eb_transport_t transportp, eb_device_t devicep) {
  struct eb_socket* socket;
  struct eb_transport* transport;
  struct eb_device* device;
  struct eb_link* link;
  eb_link_t linkp;
  int len, keep;
  uint8_t buffer[sizeof(eb_max_align_t)*(255+255+1+1)]; /* big enough for worst-case record without header */
  uint8_t* wptr, * rptr, * eos;
  uint64_t error;
  eb_width_t widths, biggest, data;
#ifdef ANAL
  eb_data_t data_mask;
  eb_address_t address_mask;
#endif
  int alignment, record_alignment, header_alignment, stride, cycle;
  int reply, header, passive, active;
  
  transport = EB_TRANSPORT(transportp);
  socket = EB_SOCKET(socketp);
  
  if (devicep != EB_NULL) {
    device = EB_DEVICE(devicep);
    
    linkp = device->link;
    if (linkp == EB_NULL) return; /* Busted link? */
    link = EB_LINK(linkp);
    
    widths = device->widths;
    header = widths == 0;
    
    passive = device->passive == devicep;
    active = !passive;
  } else {
    linkp = EB_NULL;
    link = 0;
    
    widths = 0;
    header = 1;
    
    active = 0;
    passive = 0;
  }
  
  /* Cases:
   *   passive device
   *     needing probe request
   *   active device
   *     needing probe response
   *   transport
   *     always needs EB header
   */

  reply = 0;
  len = eb_transports[transport->link_type].poll(transport, link, buffer, sizeof(buffer));
  if (len == 0) return; /* no data ready */
  if (len < 2) goto kill; /* EB is always 2 byte aligned */
  
  /* Expect and require an EB header */
  if (header) {
    /* On a stream, EB header may not be fragmented */
    if (buffer[0] != 0x4E || buffer[1] != 0x6F || len < 4) goto kill;
    
    /* Is this a probe? */
    if ((buffer[2] & 0x1) != 0) { /* probe flag */
      if (len != 8) goto kill; /* > 8: requestor couldn't send data before we respond! */
                               /* < 8: protocol violation! */
      if (active) goto kill; /* active link not probed! */
      
      buffer[2] = 0x12; /* V1 probe response */
      buffer[3] = socket->widths; /* passive and transport both use socket widths */
      
      /* Bytes 4-7 are echoed back */
      eb_transports[transport->link_type].send(transport, link, buffer, 8);
      
      return;
    }
    
    /* Is this a probe response? */
    if ((buffer[2] & 0x2) != 0) { /* probe response */
      eb_device_t devp;
      struct eb_device* dev;
      
      if (len != 8) goto kill; /* > 8: haven't sent requests, passive should not send data */
                               /* < 8: protocol violation! */
      if (passive) goto kill; /* passive link not responded! */
      
      /* Find device by probe id */
      eb_address_t tag;
      tag = be32toh(*(uint32_t*)&buffer[4]);
      
      for (devp = socket->first_device; devp != EB_NULL; devp = dev->next) {
        dev = EB_DEVICE(devp);
        if (((uint32_t)devp) == tag) break;
      }
      if (devp == EB_NULL) goto kill;
      
      dev->widths = buffer[3];
      
      return;
    } 
    
    /* Neither probe nor response, yet multiple widths? fail */
    widths = buffer[3];
    if (!eb_width_refined(widths)) goto kill;
    
    /* Unsupported widths? fail */
    widths &= socket->widths;
    if (!eb_width_possible(widths)) goto kill;
  }
  
#ifdef ANAL
  /* Determine alignment and masking sets */
  data_mask = ((eb_data_t)1) << (((widths&EB_DATAX)<<3)-1);
  data_mask = (data_mask-1) << 1 | 1;
  address_mask = ((eb_address_t)1) << (((widths&EB_ADDRX)>>1)-1);
  address_mask = (address_mask-1) << 1 | 1;
#endif

  /* Alignment is either 2, 4, or 8. */
  data = widths & EB_DATAX;
  biggest = (widths >> 4) | data;
  alignment = 2;
  alignment += (biggest >= EB_DATA32)*2;
  alignment += (biggest >= EB_DATA64)*4;
  record_alignment = 4;
  record_alignment += (biggest >= EB_DATA64)*4;
  header_alignment = record_alignment;
  /* FIFO stride size */
  stride = 1;
  stride += (data >= EB_DATA16)*1;
  stride += (data >= EB_DATA32)*2;
  stride += (data >= EB_DATA64)*4;
  
  /* Setup the initial pointers */
  wptr = &buffer[0];
  if (header) wptr += header_alignment;
  rptr = wptr;
  eos = &buffer[len];
  
  /* Session-limited error shift */
  error = 0;
  cycle = 1;

resume_cycle:
  /* Below this point, assume no dereferenced pointer is valid */

  /* Start processing the payload */
  while (rptr <= eos - record_alignment) {
    int total, wconfig, wfifo, rconfig, rfifo, bconfig;
    eb_address_t bwa, bra, ra;
    eb_data_t wv;
    uint8_t flags  = rptr[0];
    uint8_t wcount = rptr[2];
    uint8_t rcount = rptr[3];
    
    rptr += record_alignment;
    
    /* Is the cycle flag high? */
    cycle = flags & 0x08;
    
    total = wcount;
    total += rcount;
    total += (wcount>0);
    total += (rcount>0);
    
    /* Test if record overflows packet */
    while (total*alignment > eos-rptr) {
      transport = EB_TRANSPORT(transportp);
      if (linkp != EB_NULL) link = EB_LINK(linkp);
      
      /* If not a streaming socket, this is a critical error */
      if (eb_transports[transport->link_type].mtu != 0) goto kill;
      
      /* Streaming beyond this point */
      
      if (reply) {
        eb_transports[transport->link_type].send(transport, link, buffer, wptr - &buffer[0]);
      }
      
      keep = eos-rptr;
      if (rptr != &buffer[0]) memmove(&buffer[0], rptr, keep);
      
      len = eb_transports[transport->link_type].recv(transport, link, buffer+keep, sizeof(buffer)-keep);
      if (len <= 0) goto kill;
      len += keep;
      
      wptr = rptr = &buffer[0];
      eos = rptr + len;
    }
    
    if (wcount > 0) {
      wfifo = flags & 0x02;
      wconfig = flags & 0x04;
      
      bwa = EB_LOAD(rptr, alignment);
#ifdef ANAL
      if ((bwa & address_mask) != 0) goto fail;
#endif
      rptr += alignment;
      
      while (wcount--) {
        wv = EB_LOAD(rptr, alignment);
        rptr += alignment;
#ifdef ANAL
        if ((wv & data_mask) != 0) goto fail;
#endif
        if (wconfig)
          eb_socket_write_config(socketp, widths, bwa, wv);
        else
          eb_socket_write(socketp, widths, bwa, wv, &error);
        if (wfifo == 0) bwa += stride;
      }
    }
    
    if (rcount > 0) {
      reply = 1;
      rfifo = flags & 0x20;
      bconfig = flags & 0x40;
      rconfig = flags & 0x80;
      
      /* Impossible to run out of space; sizeof(request) >= sizeof(reply) */
      
      /* Prepare new header */
      memset(wptr, 0, record_alignment);
      wptr[0] = cycle | ((bconfig | rfifo) >> 4);
      wptr[1] = 0;
      wptr[2] = rcount;
      wptr[3] = 0;
      
      wptr += record_alignment;
      
      bra = EB_LOAD(rptr, alignment);
#ifdef ANAL
      if ((bra & address_mask) != 0) goto fail;
#endif
      rptr += alignment;
      
      /* Echo back the base return address */
      EB_sWRITE(wptr, bra, alignment);
      wptr += alignment;
      
      while (rcount--) {
        ra = EB_LOAD(rptr, alignment);
        rptr += alignment;
#ifdef ANAL
        if ((ra & address_mask) != 0) goto fail;
#endif
        if (rconfig)
          wv = eb_socket_read_config(socketp, widths, ra, error);
        else
          wv = eb_socket_read(socketp, widths, ra, &error);
        
        EB_sWRITE(wptr, wv, alignment);
        wptr += alignment;
      }
    }
  }
  
  /* Reply if needed */
  if (reply) {
    eb_transports[transport->link_type].send(transport, link, buffer, wptr - &buffer[0]);
  }
  
  /* Is the cycle line still high? */
  if (cycle == 0) {
    /* Only streaming sockets may keep cycle line high */
    if (eb_transports[transport->link_type].mtu != 0) goto kill;
    
    keep = eos-rptr;
    if (rptr != &buffer[0]) memmove(&buffer[0], rptr, keep);
    
    len = eb_transports[transport->link_type].recv(transport, link, buffer+keep, sizeof(buffer)-keep);
    if (len <= 0) goto kill;
    len += keep;
    
    wptr = rptr = &buffer[0];
    eos = rptr + len;
    goto resume_cycle;
  }
  
  /* Improperly terminated message? */
  if (rptr != eos) goto kill;
  
  return;
  
kill:
  /* Destroy the connection */
  if (devicep == EB_NULL) return;
  
  if (passive) {
    eb_device_close(devicep);
  } else {
    device = EB_DEVICE(devicep);
    transport = EB_TRANSPORT(transportp);
    link = EB_LINK(linkp);
    
    eb_transports[transport->link_type].disconnect(transport, link);
    eb_free_link(device->link);
    device->link = EB_NULL;
  }
}
