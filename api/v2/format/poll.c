/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements polling all sockets for readiness.
 */

#include <string.h>
#include <errno.h>

#include "../transport/transport.h"
#include "../glue/socket.h"
#include "../glue/device.h"
#include "../glue/widths.h"
#include "../memory/memory.h"
#include "bigendian.h"

static inline eb_data_t EB_LOAD(uint8_t* rptr, int alignment) {
  switch (alignment) {
  case 2: return be16toh(*(uint16_t*)rptr);
  case 4: return be32toh(*(uint32_t*)rptr);
  case 8: return be64toh(*(uint64_t*)rptr);
  }
  return 0; /* unreachable */
}

static inline void EB_WRITE(uint8_t* rptr, eb_data_t val, int alignment) {
  switch (alignment) {
  case 2: *(uint16_t*)rptr = htobe16(val);
  case 4: *(uint32_t*)rptr = htobe32(val);
  case 8: *(uint64_t*)rptr = htobe64(val);
  }
}

static void eb_link_poll(struct eb_socket* socket, struct eb_transport* transport, eb_device_t devicep, struct eb_device* device) {
  struct eb_link* link;
  eb_link_t linkp;
  int len, keep;
  uint8_t buffer[2048];
  uint8_t* wptr, * rptr, * eos;
  uint64_t error;
  eb_width_t widths, biggest, data;
#ifdef ANAL
  eb_data_t data_mask;
  eb_address_t address_mask;
#endif
  int alignment, record_alignment, stride;
  int reply;
  
  if (device) {
    linkp = device->link;
    if (linkp == EB_NULL) return;
    link = EB_LINK(linkp);
    widths = device->widths;
  } else {
    link = 0;
    widths = 0;
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
  if (len == -1 && errno == EAGAIN) return; /* no data ready */
  if (len < 2) goto kill; /* EB is always 2 byte aligned */
  
  /* Expect and require an EB header */
  if (widths == 0) {
    /* On a stream, EB header may not be fragmented */
    if (buffer[0] != 0x4E || buffer[1] != 0x6F || len < 4) goto kill;
    
    /* Is this a probe? */
    if ((buffer[2] & 0x1) != 0) { /* probe flag */
      if (len != 8) goto kill; /* > 8: requestor couldn't send data before we respond! */
                               /* < 8: protocol violation! */
      if (device && device->passive != devicep) goto kill; /* active link not probed! */
      
      buffer[2] = 0x12; /* V1 probe response */
      buffer[3] = socket->widths; /* passive and transport both use socket widths */
      
      /* Bytes 4-7 are echoed back */
      eb_transports[transport->link_type].send(transport, link, buffer, 8);
      
      return;
    }
    
    /* Is this a probe response? */
    if ((buffer[2] & 0x2) != 0) { /* probe response */
      if (len != 8) goto kill; /* > 8: haven't sent requests, passive should not send data */
                               /* < 8: protocol violation! */
      if (device && device->passive == devicep) goto kill; /* passive link not responded! */
      
      if (device) {
        device->widths = buffer[3];
      } else {
        /* Find device by probe id */
        eb_device_t devp;
        struct eb_device* dev;
        
        eb_address_t tag;
        tag = be32toh(*(uint32_t*)&buffer[4]);
        
        for (devp = socket->first_device; devp != EB_NULL; devp = device->next) {
          dev = EB_DEVICE(devp);
          if (((uint32_t)devp) == tag) break;
        }
        if (devp == EB_NULL) goto kill;
        
        dev->widths = buffer[3];
      }
      
      return;
    } 
    
    /* Neither probe nor response, yet multiple widths? fail */
    widths = buffer[3] & socket->widths;
    if (!eb_width_refined(widths)) goto kill;
    
    /* Start past the header */
    rptr = wptr = &buffer[4];
  } else {
    rptr = wptr = &buffer[0];
  }
  
#ifdef ANAL
  /* Determine alignment and masking sets */
  data_mask = ((eb_data_t)1) << (((widths&EB_DATAX)<<3)-1);
  data_mask = (data_mask-1) << 1 | 1;
  address_mask = ((eb_address_t)1) << (((widths&EB_ADDRX)>>1)-1);
  address_mask = (address_mask-1) << 1 | 1;
#endif

  /* Alignment is either 2, 4, or 8. */
  biggest = (widths >> 4) | widths;
  alignment = 2;
  alignment += (biggest >= EB_DATA32)*2;
  alignment += (biggest >= EB_DATA64)*4;
  record_alignment = 4;
  record_alignment += (biggest >= EB_DATA64)*4;
  /* FIFO stride size */
  data = widths & EB_DATAX;
  stride = 1;
  stride += (data >= EB_DATA16)*1;
  stride += (data >= EB_DATA32)*2;
  stride += (data >= EB_DATA64)*4;
  
  /* Calculate header limits */
  eos = &buffer[len];
  
  /* Start processing the payload */
  error = 0;
  while (rptr <= eos - record_alignment) {
    int total, wconfig, wfifo, rconfig, rfifo, bconfig, cycle;
    eb_address_t bwa, bra, ra;
    eb_data_t wv;
    uint8_t flags  = rptr[0];
    uint8_t wcount = rptr[2];
    uint8_t rcount = rptr[3];
    
    rptr += record_alignment;
    
    total = wcount;
    total += rcount;
    total += (wcount>0);
    total += (rcount>0);
    
    /* Test if record overflows packet */
    keep = eos-rptr;
    while (total*alignment > keep) {
      /* If not a streaming socket, this is a critical error */
      if (eb_transports[transport->link_type].mtu != 0) goto kill;
      
      /* Streaming beyond this point */
      
      if (reply) {
        eb_transports[transport->link_type].send(transport, link, buffer, wptr - &buffer[0]);
      }
      
      keep = eos-rptr;
      memmove(buffer, rptr, keep);
      
      len = eb_transports[transport->link_type].recv(transport, link, buffer+keep, sizeof(buffer)-keep);
      if (len <= 0) goto kill;
      len += keep;
      keep = len;
      
      wptr = rptr = &buffer[0];
      eos = rptr+len;
    }
    
    if (wcount > 0) {
      wfifo = flags & 0x40;
      wconfig = flags & 0x20;
      
      bwa = EB_LOAD(rptr, alignment);
#ifdef ANAL
      if ((bwa & address_mask) != 0) goto fail;
#endif
      rptr += alignment;
      
      while (wcount--) {
        wv = EB_LOAD(rptr, alignment);
#ifdef ANAL
        if ((wv & data_mask) != 0) goto fail;
#endif
        rptr += alignment;
        // Process !!! (bwa, wv)
        
        if (wfifo == 0) bwa += stride;
      }
    }
    
    if (rcount > 0) {
      reply = 1;
      rfifo = flags & 0x04;
      bconfig = flags & 0x02;
      rconfig = flags & 0x01;
      cycle = flags & 0x10;
      
      /* Impossible to run out of space; sizeof(request) >= sizeof(reply) */
      
      /* Prepare new header */
      memset(wptr, 0, record_alignment);
      wptr[0] = cycle | ((bconfig | rfifo) << 4);
      wptr[1] = 0;
      wptr[2] = rcount;
      wptr[3] = 0;
      
      wptr += record_alignment;
      
      bra = EB_LOAD(rptr, alignment);
#ifdef ANAL
      if ((bra & address_mask) != 0) goto fail;
#endif
      rptr += alignment;
      
      while (rcount--) {
        ra = EB_LOAD(rptr, alignment);
#ifdef ANAL
        if ((ra & address_mask) != 0) goto fail;
#endif
        rptr += alignment;
        
        // Process !!! (ra)
        EB_WRITE(wptr, wv, alignment);
        wptr += alignment;
      }
    }
    
  }
  
  /* Improperly terminated message? */
  if (rptr != eos) goto kill;
  
  /* Reply if needed */
  if (reply) {
    eb_transports[transport->link_type].send(transport, link, buffer, wptr - &buffer[0]);
  }
  return;
  
kill:
  /* Destroy the connection */
  if (!device) return;
  
  if (device->passive == devicep) {
    eb_device_close(devicep);
  } else {
    eb_transports[transport->link_type].disconnect(transport, link);
    eb_free_link(device->link);
    device->link = EB_NULL;
  }
}

eb_status_t eb_socket_poll(eb_socket_t socketp) {
  struct eb_socket* socket;
  struct eb_device* device;
  struct eb_transport* transport;
  struct eb_response* response;
  eb_device_t devicep;
  eb_transport_t transportp;
  
  socket = EB_SOCKET(socketp);
  
  /* Step 1. Kill any expired timeouts */
  // gettimeofday(&start, 0);
  // !!!
  
  /* Step 2. Check all devices */
  
  /* Poll all the transports */
  for (transportp = socket->first_transport; transportp != EB_NULL; transportp = transport->next) {
    transport = EB_TRANSPORT(transportp);
    eb_link_poll(socket, transport, EB_NULL, 0);
  }
  
  /* Add all the sockets to the listen set */
  for (devicep = socket->first_device; devicep != EB_NULL; devicep = device->next) {
    device = EB_DEVICE(devicep);
    
    transportp = device->transport;
    transport = EB_TRANSPORT(transportp);
    
    eb_link_poll(socket, transport, devicep, device);
  }
}
