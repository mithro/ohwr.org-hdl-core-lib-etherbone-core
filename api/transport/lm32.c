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


typedef unsigned int adress_type_t;

const adress_type_t MAC   = 1;
const adress_type_t IP    = 2;
const adress_type_t PORT  = 3;

static char* strsplit(const char*  numstr, const char* delimeter);
static unsigned char* numStrToBytes(const char*  numstr, unsigned char* bytes,  unsigned char len,  unsigned char base, const char* delimeter);
static unsigned char* addressStrToBytes(const char* addressStr, unsigned char* addressBytes, adress_type_t addtype);

  

char* strsplit(const char*  numstr, const char* delimeter)
{
	char * pch = (char*)numstr;
	
	while (*(pch) != '\0') 
		if(*(pch++) == *delimeter) return pch;		
	
 	return pch;
}
 
unsigned char* numStrToBytes(const char*  numstr, unsigned char* bytes,  unsigned char len,  unsigned char base, const char* delimeter)
{
	char * pch;
	char * pend;
	unsigned char byteCount=0;
	long tmpconv;	
	pch = (char *) numstr;

	while ((pch != NULL) && byteCount < len )
	{					
		pend = strsplit(pch, delimeter)-1;
		tmpconv = strtol((const char *)pch, &(pend), base);
		// in case of a 16 bit value		
		if(tmpconv > 255) 	bytes[byteCount++] = (unsigned char)(tmpconv>>8 & 0xff);
		bytes[byteCount++] = (unsigned char)(tmpconv & 0xff);					
		pch = pend+1;
	}
 	return bytes;
}

  unsigned char* addressStrToBytes(const char* addressStr, unsigned char* addressBytes, adress_type_t addtype)
  {
	unsigned char len;
	unsigned char base;
	char del;
	printf ("hallo\n");
	
	if(addtype == MAC)		
	{
		len 	  =  6;
		base 	  = 16;
		del 	  = ':';
		
	}
	else if(addtype == IP)				 
	{
		len 	  =  4;
		base 	  = 10;
		del 	  = '.';
	}
	
	
	else{
	printf ("error\n");
	 return NULL;	
	}
	
	
	return numStrToBytes(addressStr, addressBytes, len, base, &del);
	
} 

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
  char * pch;
  eb_status_t stat = EB_FAIL;

  link = (struct eb_lm32_udp_link*)linkp;


   
	
	//a proper address string must contain, MAC, IP and port: "hw/11:22:33:44:55:66/udp/192.168.0.1/port/60368"
	//parse and fill link struct

	pch = address;
	if(pch != NULL)
	{
		if(strncmp("hw", pch, 2) == 0)
		{
			pch = strsplit(pch,"/");
			if(pch != NULL)
			{
				addressStrToBytes((const char*)pch, link->mac, MAC);
				pch = strsplit(pch,"/");
				if(pch != NULL)
				{
					if(strncmp("udp", pch, 3) == 0)
					{
						pch = strsplit(pch,"/");
						if(pch != NULL)	addressStrToBytes(pch, link->ipv4, IP);
						pch = strsplit(pch,"/");
						if(pch != NULL)
						if(strncmp("port", pch, 4) == 0)
						{
							pch = strsplit(pch,"/");
							if(pch != NULL)
							{
								addressStrToBytes(pch, link->port, PORT);
								stat = EB_OK;
							}		
						}		
					}
				}
			}
		}
	}

	return stat;

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

