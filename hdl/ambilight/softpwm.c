// This file has been prepared for Doxygen automatic documentation generation.




#include <inttypes.h>
#include <stdio.h>
#include <util/delay.h>
#include <avr/pgmspace.h>

#include <avr/eeprom.h>
#include <avr/interrupt.h>
#include "softpwm.h"
#include "irmp.h"
#include "irmpconfig.h"

//! global buffers
volatile uint8_t compare[CHMAX];
volatile uint8_t compbuff[CHMAX];
volatile uint8_t H[LEDMAX];
volatile uint8_t V[LEDMAX];

volatile uint16_t sleep_time;
volatile uint8_t coltimer, t_col, t_inc, sleep_active, blink, blink_color, choose_led, power_down; 


#ifndef F_CPU
#error F_CPU unkown
#endif

/*
ISR(INT1_vect)
{
	static uint8_t debounce = 0xFF;
	//wakeup
	debounce = PIND && (1 << PD3);
	_delay_ms(5);
	if((PIND && (1 << PD3) && debounce) == 0)
	{
		GICR 	&= ~(1 << INT1);
		GIFR	= 0xFF;
		TIFR 	= 0xFF;   
		TIMSK 	= (1 << TOIE0) | (1 << TOIE2) | (1 << OCIE1A); 
	}
	else MCUCR = (1 << SM1); 

	
}
*/

ISR(TIMER1_COMPA_vect)
{
  (void) irmp_ISR();                                                        // call irmp ISR
}

ISR(TIMER2_OVF_vect)
{
  	static uint8_t sec_cntr = 0;            // update outputs
	static uint16_t sleep_cntr = 0;
  	static uint8_t	blink_state = BLINK_SAVE;
	static uint8_t this_led = 0;
	static uint8_t all_leds = LEDMAX;
 
	static uint8_t H_bak[LEDMAX], V_bak[LEDMAX], t_inc_bak;

  	if(++sec_cntr == TIMER2_SEC) 
	{
		sec_cntr = 0;
		
		// Blinker
			switch(blink_state)
			{			

				case BLINK_SAVE :	if(blink) 
									{
										if(choose_led >= LEDMAX) 
										{
											this_led = 0;
											all_leds = LEDMAX;
										}
										else 
										{
											this_led = choose_led;
											all_leds = choose_led+1;
										}

										
										t_inc_bak	= t_inc;
										for(uint8_t  i = this_led; i < all_leds; i++) 
										{
											//save values
											H_bak[i] 	= H[i];
											V_bak[i] 	= V[i];					
										}
										blink_state = BLINK_LO0;
									}
									else
									break;											

				case BLINK_LO0	:	t_inc		= COLOR_CONST;
									for(uint8_t  i = this_led; i < all_leds; i++) V[i]		= 0x00;
									update_pwm();
									blink_state = BLINK_COL;
									break;
										
				case BLINK_COL	:	for(uint8_t  i = this_led; i < all_leds; i++) 
									{
										H[i]		= blink_color;
										V[i]		= 0xFF;
									}
									update_pwm(); 
									blink_state = BLINK_LOAD;
									break;	
				
				
				case BLINK_LOAD	:	if(blink) 
									{
										blink_state = BLINK_LO0;
										blink--;
									}
									else
									{
										t_inc = t_inc_bak;
										for(uint8_t  i = this_led; i < all_leds; i++) 
										{
											H[i] = H_bak[i];
											V[i] = V_bak[i];	
										}
										update_pwm();
										blink_state = BLINK_SAVE;
									}
									
									break;	
			
				default			:	blink = 0;
			}



		
		// Sleep Timer
		if(sleep_active)
		{
			if(++sleep_cntr == sleep_time) 
			{
				cli();					//  | make atomic
																//	|
				TIMSK 	= (1 << OCIE1A);//	| timer IRQs deaktivieren
				TIFR 	= 0xFF; 		//	|
				TCCR2	= 0; 				
				TCCR0 	= 0;
			
				PORTD	&= ~PORTD_MASK;	//	| output abschalten
				PORTB	&= ~PORTB_MASK;	//	|		
			
			
				_delay_ms(150);			//	|
				power_down = TRUE;		//	| wakeup einrichten
				sei();

			}
			//if(++sleep_cntr > sleep_time) //deactivate timer0 and timer2
		} 
	}
  		
 
}


ISR(TIMER0_OVF_vect)
{
 	static uint8_t pinlevelB = 0; 
  	static uint8_t pinlevelD = 0;            // update outputs
	static uint8_t softcount = 0;
PORTB = pinlevelB; 	
PORTD = pinlevelD;
++softcount;
if((softcount && 0x7F) == 0){         // increment modulo 256 counter and update
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

  	pinlevelB = PORTB_MASK;     // set all port pins high
    pinlevelD = PORTD_MASK;     // set all port pins high
	coltimer += t_inc;
  }

  // clear port pin on compare match (executed on next interrupt)

  if(compare[0] == softcount) LED_0R_CLR; 
  if(compare[1] == softcount) LED_0G_CLR; 
  if(compare[2] == softcount) LED_0B_CLR; 

  if(compare[3] == softcount)  LED_1R_CLR;
  if(compare[4] == softcount)  LED_1G_CLR;
  if(compare[5] == softcount)  LED_1B_CLR;

  if(compare[6] == softcount)  LED_2R_CLR;
  if(compare[7] == softcount)  LED_2G_CLR;
  if(compare[8] == softcount)  LED_2B_CLR;

  if(compare[9] == softcount)  LED_3R_CLR;
  if(compare[10] == softcount) LED_3G_CLR;
  if(compare[11] == softcount) LED_3B_CLR;

}
void config(uint8_t action)
{
    
/*	
	uint8_t myByte;
 
    myByte = eeprom_read_byte(&eeFooByte); // lesen
    // myByte hat nun den Wert 123
//...
    myByte = 99;
    eeprom_write_byte(&eeFooByte, myByte); // schreiben
    // der Wert 99 wird im EEPROM an die Adresse der
    // 'Variablen' eeFooByte geschrieben
//...
    myByte = eeprom_read_byte(&eeFooByteArray1[1]); 
*/
}


void timer_init(void)
{
	OCR1A   = (F_CPU / F_INTERRUPTS) - 1;	
  	TIFR 	= 0xFF;           								// clear interrupt flags
  	TIMSK 	= (1 << TOIE0) | (1 << OCIE1A) | (1 << TOIE2) ;  // enable overflow interrupt 0 & 2, outputcompare 1, 
  	
	TCCR2	= (1 << CS22) 	| (1 << CS21); 					// 256er prescale 
	TCCR1B  = (1 << WGM12) 	| (1 << CS10);  				// CTC, no prescale
	TCCR0 	= (1 << CS00);	
}

void init(void)
{
  	uint8_t  i;

  	timer_init();        							// no prescale
	irmp_init(); 											// will set PD3 to input, no pullup. 
	
	DDRD 	= PORTD_MASK;            						// set port pins to output
 	DDRB 	= PORTB_MASK;            						// set port pins to output

	for(i=0 ; i<LEDMAX ; i++)      							// initialise all PWM channels
  	{
    	uint8_t  V_tmp, R, HR, G, HG, B, HB;
		
		H[i] = i*H_DEFAULT_DIFF;
		V[i] = V_DEFAULT;

		HR = H[0];
		HG = H[0] + 85;		
		HB = H[0] + 170;

		R = RGB[HR]; 
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

void update_pwm()
{
	
 // soft irq!
	

	for(uint8_t  i=0; i < LEDMAX; i++)      // initialise all channels
  	{
     	uint8_t  V_tmp, R, HR, G, HG, B, HB;
		uint16_t mul_tmp;		

		HR = H[i];
		HG = H[i] + 95;		
		HB = H[i] + 180;

		R = RGB[HR];  // divide by 4 to resize 0-255 H value to 0-63 array index
		G = RGB[HG];
		B = RGB[HB];

		V_tmp = V[i];
		
		mul_tmp = R * V_tmp;
		R = (mul_tmp>>8);
		mul_tmp = G * V_tmp;
		G = (mul_tmp>>8);
		mul_tmp = B * V_tmp;
		B = (mul_tmp>>8);
	
		
		uint8_t sreg = SREG;	
		cli();	
		
		compbuff[i*COLMAX+0] = R;
    	compbuff[i*COLMAX+1] = G;
		compbuff[i*COLMAX+2] = B;

		SREG = sreg;
		sei();         		// enable interrupts
	}
}



int main(void)
{
  	uint16_t command_tmp, address_tmp;
	IRMP_DATA irmp_data;
	
	uint8_t this_led, all_leds;
	
	choose_led = LEDMAX;

	init();

	power_down = FALSE;	

	for(;;)
  	{
		if(coltimer >= t_col) 
		{	coltimer = 0;
			for(uint8_t  i = 0; i < LEDMAX; i++) {H[i] += 1;} 
	
			
			update_pwm();	
		}
		
		if(choose_led >= LEDMAX) 
		{
			this_led = 0;
			all_leds = LEDMAX;
		}
		else
		{
			this_led = choose_led;
			all_leds = choose_led+1;
		}
				

		if (irmp_get_data (&irmp_data))
    	{
			

			command_tmp = irmp_data.command;
        	address_tmp = irmp_data.address;
		
       		if(power_down)
			{//wake up!
				 if(command_tmp == IRC_OFF)
				 {
				 		
				 }
				 else
				 {
				 	timer_init();
				 		power_down = FALSE;
				 }	
			}
			else
			{
				if(blink == 0)
				{
				switch(command_tmp)
				{
					case IRC_OFF: 		//save config
									
									
										cli();					//  | make atomic
																//	|
										TIMSK 	= (1 << OCIE1A);//	| timer IRQs deaktivieren
										TIFR 	= 0xFF; 		//	|
										TCCR2	= 0; 				
										TCCR0 	= 0;
									
										PORTD	&= ~PORTD_MASK;	//	| output abschalten
										PORTB	&= ~PORTB_MASK;	//	|		
									
									
										_delay_ms(150);			//	|
										power_down = TRUE;		//	| wakeup einrichten
										sei();					//	|
									
										break;
				
					case IRC_T_INC: 	//farben rotieren langsamer 
										t_col = (t_col < 255) ? t_col+1 : t_col; 
										break;

					case IRC_T_DEC	: 	//farben rotieren schneller
										t_col = (t_col > 1) ? t_col-1 : 1;
										break;

					case IRC_SHFT	: 	//farben rotieren oder constant
										if(t_inc == COLOR_SHIFT)
										{
											t_inc = COLOR_CONST;
											blink_color = H_BLINK_RED; 
										
										}
										else
										{
											t_inc = COLOR_SHIFT;
											blink_color = H_BLINK_GRN; 
										}
										blink = 1;							
										break;

					case IRC_CHOOSE_L: 	if(choose_led == 0) choose_led = LEDMAX;
										else choose_led--;
										blink = 1;
										blink_color = H_BLINK_GRN;

										break;

					case IRC_CHOOSE_R	: if(choose_led == LEDMAX) choose_led = 0;
										  else choose_led++;		//Nur 1 Farbe
										blink = 1;
										blink_color = H_BLINK_GRN;
										break;

					case IRC_H_INC	:   //H erhöhen
										for(uint8_t  i = this_led; i < all_leds; i++) H[i]  += 2;
										break;

					case IRC_H_DEC	: 	//H erniedrigen
										for(uint8_t  i = this_led; i < all_leds; i++) H[i]  -= 2;
										break;

					case IRC_V_INC	: 	//V erhöhen
										for(uint8_t  i = this_led; i < all_leds; i++)
										{
											uint8_t V_tmp;
										
											V_tmp = V[i];
											V_tmp = (V_tmp < (0xFF - RC_INCDEC)) ? V_tmp+RC_INCDEC : V_tmp; 
											V[i]  = V_tmp;

										}
									
										break;

					case IRC_V_DEC	: 	//V erniedrigen
										for(uint8_t  i = this_led; i < all_leds; i++)
										{
											uint8_t V_tmp;
										
											V_tmp = V[i];
											V_tmp = (V_tmp > RC_INCDEC) ? V_tmp-RC_INCDEC : 0; 
											V[i]  = V_tmp;

										}
										break;
				
					case IRC_SLP_STOP :	sleep_time = 0;
										sleep_active = FALSE;

										blink = 1;
										blink_color = H_BLINK_RED;
										choose_led = LEDMAX; 
										break;				


					case IRC_SLP_1 :	sleep_time = 10 * 5;//600;
										sleep_active = TRUE;
										blink = 1;
										blink_color = H_BLINK_GRN;
  										choose_led = 0; 
										break;
				
					case IRC_SLP_2 :	sleep_time = 20 * 600;
										sleep_active = TRUE;
										blink = 2;
										blink_color = H_BLINK_GRN;
										choose_led = LEDMAX;  
										break;

					case IRC_SLP_3 :	sleep_time = 30 * 600;
										sleep_active = TRUE;
										blink = 3;
										blink_color = H_BLINK_GRN;
										choose_led = LEDMAX;   
										break;
				
					case IRC_SLP_4 :	sleep_time = 40 * 600;
										sleep_active = TRUE;
										blink = 4;
										blink_color = H_BLINK_GRN;
										choose_led = LEDMAX;   
										break;


					case IRC_SLP_5 :	sleep_time = 50 * 600;
										sleep_active = TRUE;
										blink = 5;
										blink_color = H_BLINK_GRN; 
										break;
				
					case IRC_SLP_6 :	sleep_time = 60 * 600;
										sleep_active = TRUE;
										blink = 6;
										blink_color = H_BLINK_GRN;
										choose_led = LEDMAX;   
										break;

					case IRC_SLP_7 :	sleep_time = 70 * 600;
										sleep_active = TRUE;
										blink = 7;
										blink_color = H_BLINK_GRN; 
										choose_led = LEDMAX;  
										break;
				
					case IRC_SLP_8 :	sleep_time = 80 * 600;
										sleep_active = TRUE;
										blink = 8;
										blink_color = H_BLINK_GRN;
										choose_led = LEDMAX;   
										break;

					case IRC_SLP_9 :	sleep_time = 90 * 600;
										sleep_active = TRUE;
										blink = 9;
										blink_color = H_BLINK_GRN;
										choose_led = LEDMAX;   
										break;

					default		:		break;
				}
				}
			if(t_inc == COLOR_CONST) update_pwm();
			}
			
													
		}	

			
		
  	}
	return 0;
}







