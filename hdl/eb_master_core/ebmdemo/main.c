#include <stdio.h>
#include "display.h"
#include "irq.h"
#include "ebm.h"

volatile unsigned int* display    = (unsigned int*)0x02900000;
volatile unsigned int* irq_slave  = (unsigned int*)0x02000d00;
volatile unsigned int* ebm        = (unsigned int*)0x01000000;


char* mat_sprinthex(char* buffer, unsigned long val)
{
	unsigned char i,ascii;
	const unsigned long mask = 0x0000000F;

	for(i=0; i<8;i++)
	{
		ascii= (val>>(i<<2)) & mask;
		if(ascii > 9) ascii = ascii - 10 + 'A';
	 	else 	      ascii = ascii      + '0';
		buffer[7-i] = ascii;		
	}
	
	buffer[8] = 0x00;
	return buffer;	
}

void show_msi()
{
  char buffer[12];
  
  
  disp_put_str("D ");
  disp_put_str(mat_sprinthex(buffer, global_msi.msg));
  disp_put_c('\n');

  disp_put_str("A ");
  disp_put_str(mat_sprinthex(buffer, global_msi.src));
  disp_put_c('\n');

  disp_put_str("S ");
  disp_put_str(mat_sprinthex(buffer, (unsigned long)global_msi.sel));
  disp_put_c('\n');
}


void isr0()
{
  unsigned int j;
  
  disp_put_str("ISR0\n");
  show_msi();
 
 for (j = 0; j < 125000000; ++j) {
        asm("# noop"); /* no-op the compiler can't optimize away */
      }
 disp_put_c('\f');     
}

void isr1()
{
  unsigned int j;
  
  disp_put_str("ISR1\n");
  show_msi();

   for (j = 0; j < 125000000; ++j) {
        asm("# noop"); /* no-op the compiler can't optimize away */
      }
   disp_put_c('\f');   
}

void _irq_entry(void) {
  
  disp_put_c('\f');
  disp_put_str("IRQ_ENTRY\n");
  irq_process();

   
}

const char mytext[] = "Hallo Welt!...\n\n";

void main(void) {

  isr_table_clr();
  isr_ptr_table[0]= isr0;
  isr_ptr_table[1]= isr1;  
  irq_set_mask(0x03);
  irq_enable();

  
  int i, j, xinc, yinc, x, y;

unsigned int time = 0;


	unsigned int addr_raw_off;

	char color = 0xFF;

  x = 0;
	y = 9;
	yinc = -1;
 	xinc = 1;
	addr_raw_off = 0;

  disp_reset();	
  disp_put_c('\f');
  disp_put_str(mytext);






	
	///////////////////////////////////////////////////////////////////////////////////
	//Init EB Master
	ebm_config_if(LOCAL,   "hw/08:00:30:e3:b0:5a/udp/192.168.191.254/port/60368");
	ebm_config_if(REMOTE,  "hw/bc:30:5b:e2:b0:88/udp/192.168.191.131/port/60368");
  ebm_config_meta(80, 0x11, 16, 0x00000000 );
	
  while (1) {
     //Send packet heartbeat
     
     if(time++ > 50) { 
      //create WB cycle
      ebm_op(0x55000333, 0xDEADBEEF, WRITE);
      ebm_op(0x22000333, 0xCAFEBABE, READ);  
      //send
      ebm_flush(); 
     } 
  ///////////////////////////////////////////////////////////////////////////////////




	
	

      /* Each loop iteration takes 4 cycles.
       * It runs at 125MHz.
       * Sleep 0.2 second.
       */
      

   


//  disp_put_raw( get_pixcol_val((unsigned char)y), get_pixcol_addr((unsigned char)x, (unsigned char)y), color);

for (j = 0; j < 62500000/160; ++j) {
        asm("# noop"); /* no-op the compiler can't optimize away */
              }


	if(x == 63) xinc = -1;
	if(x == 0)  xinc = 1;

	if(y == 47) yinc = -1;
	if(y == 0)  yinc = 1;

	x += xinc;
	y += yinc;

	if(time++ > 500) {time = 0; color = ~color; }
	
    
  }
}
