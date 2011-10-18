-------------------------------------------------------------------------------
-- White Rabbit Switch / GSI BEL
-------------------------------------------------------------------------------
--
-- unit name: Parallel-In/Serial-Out shift register
--
-- author: Mathias Kreider, m.kreider@gsi.de
--
-- date: $Date:: $:
--
-- version: $Rev:: $:
--
-- description: <file content, behaviour, purpose, special usage notes...>
-- <further description>
--
-- dependencies: <entity name>, ...
--
-- references: <reference one>
-- <reference two> ...
--
-- modified by: $Author:: $:
--
-------------------------------------------------------------------------------
-- last changes: <date> <initials> <log>
-- <extended description>
-------------------------------------------------------------------------------
-- TODO: <next thing to do>
-- <another thing to do>
--
-- This code is subject to GPL
-------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.wishbone_package.all;

entity wb_led_ctrl is 
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wishbone_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wishbone_slave_in;    --! 

		leds_o			: out	std_logic_vector(7 downto 0)
		
);

end wb_led_ctrl;


architecture behavioral of wb_led_ctrl is

type LED is record
	--PRE_SFD    : std_logic_vector((8*8)-1 downto 0);   
	src_sel			: 	std_logic_vector(1 downto 0);   
	src_pol			:	std_logic;
	stat_val		: 	std_logic;   	
	reserved		: 	std_logic_vector(2 downto 0);    
	pwm_pol			:	std_logic; 
	pwm_t			: 	std_logic_vector(23 downto 0);
end record;

function TO_LED(X : std_logic_vector)
return LED is
    variable tmp : LED;
    begin
        tmp.src_sel   	:= X(1 downto 0);
        tmp.src_pol   	:= X(2);
        tmp.stat_val  	:= X(3);
        pwm_pol			:= X(7);
		pwm_t         	:= X(31 downto 8);
    return tmp;
end function TO_UDP_HDR;


--offset 0x0100																
-- LED controller
subtype dword is std_logic_vector(31 downto 0);
type mem is array (0 to 7) of dword ; 
signal my_mem : mem;  

signal 	wb_adr 		: natural;


-- LEDs are active LO

-- source LO = constant
-- source HI = PWM
---> source constant LO AND PWM channel --> LO

-- state LO = off
-- state HI = on
--> NOT state LO (HI) 
--> HI OR PWM/constant --> HI

begin

wb_adr <= to_integer(unsigned(wb_slave_i.ADR(31 downto 2))); --divide by 4

	
wishbone_if	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then

			on_off 		<= (others => '0');
			source 		<= (others => '0');
			wb_slave_o	<=   (
								ACK   => '0',
								ERR   => '0',
								RTY   => '0',
								STALL => '0',
								DAT   => (others => '0'));
		else
            wb_slave_o.ACK <= wb_slave_i.CYC AND wb_slave_i.STB;
			wb_slave_o.DAT  <= (others => '1');
		
			
		
		
			if(wb_adr < 8) then	
				if(wb_slave_i.WE ='1') then
					mem(wb_adr) <= wb_slave_i.DAT;
				else
					wb_slave_o.DAT <= mem(wb_adr) AND x"FFFFFF8F";
				end if;	
			end if;
        end if;    
    end if;
end process;
  
end behavioral;