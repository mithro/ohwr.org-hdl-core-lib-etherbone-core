/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This describes the Etherbone transport interface.
 */

#ifndef EB_TRANSPORT_H
#define EB_TRANSPORT_H

#include "../etherbone.h"

typedef EB_POINTER(eb_transport_link) eb_transport_link_t;
struct eb_transort_link {
};

typedef EB_POINTER(eb_transport) eb_transport_t;
struct eb_transport {
};

struct eb_transport_ops {
   void (*open) (eb_transport_t transport);
   void (*close)(eb_transport_t transport);

   void (*connect)   (eb_transport_link_t link, const char* address); 
   void (*disconnect)(eb_transport_link_t link);
   
   // compare: match incoming udp packet to matching device request... in particular for a probe
   
   void (*recv)(eb_transport_t, eb_transport_link_t, uint8_t* buf, uint16_t* size);
   void (*send)(eb_transport_t, eb_transport_link_t, uint8_t* buf, uint16_t size);
   
/*
   descriptor(link)
   descriptor(transport)
   ==> block ??
*/
};

#endif
