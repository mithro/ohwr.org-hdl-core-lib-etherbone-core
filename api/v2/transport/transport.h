/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This describes the Etherbone transport interface.
 */

#ifndef EB_TRANSPORT_H
#define EB_TRANSPORT_H

#include "../etherbone.h"

/* The exact use of these 12-bytes is specific to the transport */
typedef EB_POINTER(eb_link) eb_link_t;
struct eb_link {
  uint8_t raw[12];
};

/* The exact use of these 8-bytes is specific to the transport */
typedef EB_POINTER(eb_transport) eb_transport_t;
struct eb_transport {
  uint8_t raw[8];
  uint8_t link_type;
  eb_transport_t next;
};

/* Each transport provides these methods */
struct eb_transport_ops {
   int mtu; /* if 0, streaming is assumed */
   
   /* ADDRESS -> simply not included. Other errors reported to user. */
   eb_status_t (*open) (struct eb_transport* transport, int port);
   void        (*close)(struct eb_transport* transport);

   /* ADDRESS -> simply not used. Other errors reported to user. */
   eb_status_t (*connect)   (struct eb_transport*, struct eb_link* link, const char* address); 
   void        (*disconnect)(struct eb_transport*, struct eb_link* link);
   
   /* IO functions */
   int  (*fdes)(struct eb_transport*, struct eb_link* link);
   int  (*poll)(struct eb_transport*, struct eb_link* link, uint8_t* buf, int len);
   int  (*recv)(struct eb_transport*, struct eb_link* link, uint8_t* buf, int len);
   void (*send)(struct eb_transport*, struct eb_link* link, uint8_t* buf, int len);
};

/* The table of all supported transports */
extern struct eb_transport_ops eb_transports[];
extern const unsigned int eb_transport_size;

#endif
