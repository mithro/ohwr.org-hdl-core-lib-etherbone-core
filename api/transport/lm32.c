/** @file lm32.c
 *  @brief Implement raw ethernet using mininic
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  All supported transports are included in the global eb_transports[].
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

#include <stdlib.h>
#include <string.h>

#include "ipv4.h"
#include "ptpd_netif.h"


struct eb_transport_ops eb_transports[] = {
  {
    EB_lm32_UDP_MTU,
    eb_lm32_udp_open,
    eb_lm32_udp_close,
    eb_lm32_udp_connect,
    eb_lm32_udp_disconnect,
    eb_lm32_udp_fdes,
    eb_lm32_udp_accept,
    eb_lm32_udp_poll,
    eb_lm32_udp_recv,
    eb_lm32_udp_send,
    eb_lm32_udp_send_buffer
  }
};

const unsigned int eb_transport_size = sizeof(eb_transports) / sizeof(struct eb_transport_ops);



eb_status_t eb_lm32_udp_open(struct eb_transport* transportp, const char* port) {

  wr_sockaddr_t saddr;
  struct eb_lm32_udp_transport* transport;
  eb_lm32_sock_t sock4;
  
  /* Configure socket filter */
  memset(&saddr, 0, sizeof(saddr));
  strcpy(saddr.if_name, port);
  
  saddr.ethertype = htons(0x0800);	/* IP */
  saddr.family = PTPD_SOCK_RAW_ETHERNET;

  sock4 = ptpd_netif_create_socket(PTPD_SOCK_RAW_ETHERNET,
					      0, &saddr);  ;
  /* Failure if we can't get a protocol */
  if (sock4 == -1) 
    return EB_BUSY;
  
  transport = (struct eb_lm32_udp_transport*)transportp;
  transport->socket4 = sock4;
  
  return EB_OK;
}


eb_status_t eb_lm32_udp_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address) {
  struct eb_lm32_udp_transport* transport;
  struct eb_lm32_udp_link* link;
  socklen_t len;
 


//TODO
//Write address parser mac/ip/port

  link->raw	 
  
  return EB_OK;
}

EB_PRIVATE void eb_lm32_udp_disconnect(struct eb_transport* transport, struct eb_link* link) {}



}






EB_PRIVATE int eb_lm32_udp_poll(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t ready, uint8_t* buf, int len)
{




}



EB_PRIVATE void eb_lm32_udp_send(struct eb_transport* transportp, struct eb_link* linkp, const uint8_t* buf, int len)
{



}

EB_PRIVATE void eb_lm32_udp_send_buffer(struct eb_transport* transportp, struct eb_link* linkp, int on) {}

EB_PRIVATE void eb_lm32_udp_fdes(struct eb_transport*, struct eb_link* link, eb_user_data_t data, eb_descriptor_callback_t cb) {}

EB_PRIVATE int eb_lm32_udp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {return 0;}

EB_PRIVATE int eb_lm32_udp_accept(struct eb_transport*, struct eb_link* result_link, eb_user_data_t data, eb_descriptor_callback_t ready)  {return 0;}

