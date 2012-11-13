/** @file lm32.h
 *  @brief This implements a UDP binding using ifnet from ptpt lm32 wrapper lib.
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  UDP links all share the same socket, only recording the target address.
 *  At the moment the target address is dynamically allocated. (!!! fixme)
 *
 *  @author Mathias Kreider <m.kreider@gsi.de>
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

#ifndef EB_LM32_UDP_H
#define EB_LM32_UDP_H

#include "ipv4.h"
#include "ptpd_netif.h"
#include "../etherbone.h"
typedef eb_descriptor_t eb_lm32_sock_t;

#define eb_lm32_udp_MTU 1472

EB_PRIVATE eb_status_t eb_lm32_udp_open(struct eb_transport* transport, const char* port);

EB_PRIVATE void eb_lm32_udp_close(struct eb_transport* transport);
EB_PRIVATE eb_status_t eb_lm32_udp_connect(struct eb_transport* transport, struct eb_link* link, const char* address);
EB_PRIVATE void eb_lm32_udp_disconnect(struct eb_transport* transport, struct eb_link* link);
EB_PRIVATE void eb_lm32_udp_fdes(struct eb_transport*, struct eb_link* link, eb_user_data_t data, eb_descriptor_callback_t cb);
EB_PRIVATE int eb_lm32_udp_accept(struct eb_transport*, struct eb_link* result_link, eb_user_data_t data, eb_descriptor_callback_t ready);
EB_PRIVATE int eb_lm32_udp_poll(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t ready, uint8_t* buf, int len);
EB_PRIVATE int eb_lm32_udp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len);
EB_PRIVATE void eb_lm32_udp_send(struct eb_transport* transportp, struct eb_link* linkp, const uint8_t* buf, int len);
EB_PRIVATE void eb_lm32_udp_send_buffer(struct eb_transport* transportp, struct eb_link* linkp, int on);

struct eb_lm32_udp_transport {
  /* Contents must fit in 9 bytes */
  eb_lm32_sock_t socket4; /* IPv4 */
};

struct eb_lm32_udp_link {
  /* Contents must fit in 12 bytes */
  struct sockaddr_storage* sa;
  socklen_t sa_len;
};

#endif
