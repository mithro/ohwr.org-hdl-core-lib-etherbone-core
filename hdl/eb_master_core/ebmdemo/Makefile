LD        := lm32-elf-ld
CC        := lm32-elf-gcc
TARGET    = ebm_udp_demo
MYPATH    = .
CHECKOUT  = ../../../../..
INCPATH   = $(CHECKOUT)/modules/lm32-include
W1        = $(CHECKOUT)/ip_cores/wrpc-sw
CFLAGS    = -std=gnu99 -I$(INCPATH) -mmultiply-enabled -mbarrel-shift-enabled -Os -I$(W1)/include -I$(W1)/pp_printf \

all: $(TARGET).bin $(TARGET).elf

$(TARGET).bin: $(TARGET).elf
	lm32-elf-objcopy -O binary $< $@

$(TARGET).elf:	$(INCPATH)/dbg.c $(INCPATH)/aux.c $(INCPATH)/ebm.c $(INCPATH)/irq.c \
		$(INCPATH)/mini_sdb.c $(MYPATH)/main.c $(INCPATH)/crt0.S $(INCPATH)/mprintf.c \
		$(W1)/dev/uart.c 
		$(CC) $(CFLAGS) -o $@ -nostdlib -T linker.ld $^ 


clean:
	rm -f *.o *.elf *.bin
