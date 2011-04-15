// This file has been prepared for Doxygen automatic documentation generation.


//#include <ctype.h>


#include <avr/interrupt.h>
#include "softpwm.h"
//#include "irmp.h"
//#include "irmpconfig.h"

//! global buffers
volatile uint8_t compare[CHMAX];
volatile uint8_t compbuff[CHMAX];
volatile uint8_t H[LEDMAX];
volatile uint8_t V[LEDMAX];
volatile uint8_t coltimer, t_col, t_inc; 
//volatile uint8_t pinlevelD, softcount;
/*
ISR(TIMER1_COMPA_vect)
{
  (void) irmp_ISR();                                                        // call irmp ISR
}
*/

ISR(TIMER0_OVF_vect)
{
 // static uint8_t pinlevelB=PORTB_MASK; 
          // update outputs
  	static uint8_t pinlevelD;            // update outputs
	static uint8_t softcount = 0; 	
PORTD = pinlevelD;
++softcount;
if((softcount && 0x3F) == 0){         // increment modulo 256 counter and update
                             // the compare values only when counter = 0.
    compare[0]  = compbuff[0];   // verbose code for speed
    compare[1]  = compbuff[1];
    compare[2]  = compbuff[2];
    compare[3]  = compbuff[3];
    compare[4]  = compbuff[4];
    compare[5]  = compbuff[5];
    compare[6]  = compbuff[6];
    compare[7]  = compbuff[7];
    compare[8]  = compbuff[8];
    compare[9]  = compbuff[9];   // last element must equal CHMAX - 1
    compare[10] = compbuff[10];
    compare[11] = compbuff[11];			

	//softcount = 0;
//    pinlevelB = PORTB_MASK;     // set all port pins high
    pinlevelD = PORTD_MASK;     // set all port pins high
	coltimer += t_inc;
  }

  // clear port pin on compare match (executed on next interrupt)
  if(compare[0] == softcount) pinlevelD &= ~(1 << PD0); // LED_0R_CLR;
  if(compare[1] == softcount) pinlevelD &= ~(1 << PD1);// LED_0G_CLR;
  if(compare[2] == softcount) pinlevelD &= ~(1 << PD2);// LED_0B_CLR;
/*
  if(compare[3] == softcount)  LED_1R_CLR;
  if(compare[4] == softcount)  LED_1G_CLR;
  if(compare[5] == softcount)  LED_1B_CLR;

  if(compare[6] == softcount)  LED_2R_CLR;
  if(compare[7] == softcount)  LED_2G_CLR;
  if(compare[8] == softcount)  LED_2B_CLR;

  if(compare[9] == softcount)  LED_3R_CLR;
  if(compare[10] == softcount) LED_3G_CLR;
  if(compare[11] == softcount) LED_3B_CLR;
*/
}



void Init(void)
{
  	uint8_t  i;

  	//irmp_init();                                                              // initialize rc5
	
//	OCR1A   = (F_CPU / F_INTERRUPTS) - 1;	
  	TIFR 	= 0xFF;           // clear interrupt flag
  	TIMSK 	= ((1 << TOIE0));// | (1 << OCIE1A));         // enable overflow interrupt
 // 	TCCR1B  = (1 << WGM12) | (1 << CS10);  
	TCCR0 	= (1 << CS00);         // start timer, no prescale

  	DDRD 	= PORTD_MASK;            // set port pins to output
//  	DDRB 	= PORTB_MASK;            // set port pins to output

	for(i=0 ; i<LEDMAX ; i++)      // initialise all channels
  	{
    	uint8_t  V_tmp, R, HR, G, HG, B, HB;
		
		H[i] = i*H_DEFAULT_DIFF;
		V[i] = V_DEFAULT;

		HR = H[0];
		HG = H[0] + 85;		
		HB = H[0] + 170;

		R = RGB[HR];  // divide by 4 to resize 0-255 H value to 0-63 array index
		G = RGB[HG];
		B = RGB[HB];
		
		
		
		compbuff[i*COLMAX+0] = R;           
    	compbuff[i*COLMAX+1] = G;
		compbuff[i*COLMAX+2] = B;  
  	}
	t_col 	= T_DEFAULT;
	t_inc 	= COLOR_SHIFT;	
	coltimer = 0;
	
	sei();         		// enable interrupts
}

void update_pwm(void)
{
	
 // soft irq!
	

  //	for(uint8_t  i=0; i < LEDMAX; i++)      // initialise all channels
 // 	{
     	uint8_t  V_tmp, R, HR, G, HG, B, HB, tmp;
		uint16_t 	mul_tmp;		

		HR = H[0];
		HG = H[0] + 95;		
		HB = H[0] + 180;

		R = RGB[HR];  // divide by 4 to resize 0-255 H value to 0-63 array index
		G = RGB[HG];
		B = RGB[HB];

		V_tmp = V[0];
		
		mul_tmp = R * V_tmp;
		R = (mul_tmp>>8);
		mul_tmp = G * V_tmp;
		G = (mul_tmp>>8);
		mul_tmp = B * V_tmp;
		B = (mul_tmp>>8);
	
		
	uint8_t sreg = SREG;	
	cli();	
		compbuff[0*COLMAX+0] = R; //(R > V_tmp) ? R - V_tmp : 0;           
    	compbuff[0*COLMAX+1] = G;//(G > V_tmp) ? G - V_tmp : 0;
		compbuff[0*COLMAX+2] = B; //(B > V_tmp) ? B - V_tmp : 0;  
	//}
	SREG = sreg;
	sei();         		// enable interrupts
}



int main(void)
{
  	//IRMP_DATA irmp_data;
	Init();

	for(;;)
  	{
		if(coltimer >= t_col) 
		{	coltimer = 0;
			for(uint8_t  i = 0; i < LEDMAX; i++) {H[i] += 1;} 
	
		
			update_pwm();	
		}
	/*
		else if (irmp_get_data (&irmp_data))
    	{
			uint16_t command_tmp, address_tmp;

			command_tmp = irmp_data.command;
        	address_tmp = irmp_data.address;
        }
	
			switch(command_tmp)
			{
				case IRC_T_INC: 	//farben rotieren langsamer 
									t_col = (t_col+1 > t_col) ? t_col+1 : t_col; 
									break;

				case IRC_T_DEC	: 	//farben rotieren schneller
									t_col = (t_col-1 < t_col) ? t_col-1 : 0;
									break;

				case IRC_SHFT	: 	//farben rotieren oder constant
									t_inc = (t_inc == COLOR_SHIFT) ? COLOR_CONST : COLOR_SHIFT;
									break;

				case IRC_MULTI	: 	//4 verschiedene Farben
									for(uint8_t  i = 0; i < LEDMAX; i++) H[i] = i*H_DEFAULT_DIFF;
									break;

				case IRC_SINGLE	: 	//Nur 1 Farbe
									for(uint8_t  i = 0; i < LEDMAX; i++) H[i] = 0;
									break;

				case IRC_H_INC	:   //H erhöhen
									H[0]  += 4;
									H[1]  += 4;
									H[2]  += 4;
									H[3]  += 4;
									break;

				case IRC_H_DEC	: 	//H erniedrigen
									H[0]  -= 4;
									H[1]  -= 4;
									H[2]  -= 4;
									H[3]  -= 4;
									break;

				case IRC_V_INC	: 	//V erhöhen
									V[0]  += 4;
									V[1]  += 4;
									V[2]  += 4;
									V[3]  += 4;
									break;

				case IRC_V_DEC	: 	//V erniedrigen
									V[0]  -= 4;
									V[1]  -= 4;
									V[2]  -= 4;
									V[3]  -= 4;
									break;
			
				default		:		break;
			}
			
			
			for(uint8_t  i = 0; i < LEDMAX; i++) 
			{
				
				
				
				V[i]  += (RED[H_tmp] > V_tmp) ? RED[H_tmp] - V_tmp : 0; V_inc;
				
				 
				H[i]  += (RED[H_tmp] > V_tmp) ? RED[H_tmp] - V_tmp : 0; H_inc;
			}
			
													
		}	
*/
			
		
  	}
	return 0;
}







