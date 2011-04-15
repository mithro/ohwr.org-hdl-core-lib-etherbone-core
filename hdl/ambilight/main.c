/*---------------------------------------------------------------------------------------------------------------------------------------------------
 * main.c - demo main module to test irmp decoder
 *
 * Copyright (c) 2009-2010 Frank Meyer - frank(at)fli4l.de
 *
 * $Id: main.c,v 1.8 2010/08/30 15:45:27 fm Exp $
 *
 * ATMEGA88 @ 8 MHz
 *
 * Fuses: lfuse: 0xE2 hfuse: 0xDC efuse: 0xF9
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *---------------------------------------------------------------------------------------------------------------------------------------------------
 */

/*---------------------------------------------------------------------------------------------------------------------------------------------------
 * uncomment this for codevision compiler:
 *---------------------------------------------------------------------------------------------------------------------------------------------------
 */

#include <inttypes.h>
//#include <avr/io.h>
#include <stdio.h>
#include <util/delay.h>
#include <avr/pgmspace.h>
#include <avr/interrupt.h>
#include "irmp.h"
#include "irmpconfig.h"
#include "lcd-routines.h"

#endif  // CODEVISION


#ifndef F_CPU
#error F_CPU unkown
#endif

void
timer_init (void)
{

  	OCR1A   =  (F_CPU / F_INTERRUPTS) - 1;                                    // compare value: 1/10000 of CPU frequency
  	TCCR1B  = (1 << WGM12) | (1 << CS10);                                     // switch CTC Mode on, set prescaler to 1
	TIMSK  = 1 << OCIE1A;                                                     // OCIE1A: Interrupt by timer compare

}

/*---------------------------------------------------------------------------------------------------------------------------------------------------
 * timer 1 compare handler, called every 1/10000 sec
 *---------------------------------------------------------------------------------------------------------------------------------------------------
*/
ISR(TIMER1_COMPA_vect)
#endif  // CODEVISION
{
  (void) irmp_ISR();                                                        // call irmp ISR
}


int
main (void)
{
  IRMP_DATA irmp_data;

  irmp_init();                                                              // initialize rc5
  timer_init(); 
                                                          // initialize timer
  sei ();                                                                   // enable interrupts

  for (;;)
  {
    if (irmp_get_data (&irmp_data))
    {
        irmp_data.address;
        irmp_data.command;

    }
  }
}


