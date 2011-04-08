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
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wishbone_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wishbone_slave_in;    --! 

		pwm_ch_i		: in	std_logic_vector(1 downto 0);
		leds_o			: out	std_logic_vector(1 downto 0)
		
    );

end wb_led_ctrl;


architecture behavioral of wb_led_ctrl is


--offset 0x0100																
-- LED controller
signal 	on_off	  	: std_logic_vector(31 downto 0);	--0x00
alias 	led_state 	:  std_logic_vector(1 downto 0) is on_off(1 downto 0);

signal 	source	  	: std_logic_vector(31 downto 0);	--0x04
alias 	led_source 	:  std_logic_vector(1 downto 0) is source(1 downto 0);	

signal 	wb_adr 		: std_logic_vector(31 downto 0);
alias 	adr			:  std_logic_vector(7 downto 0) is wb_adr(7 downto 0);

leds_o <= (pwm_ch_i AND led_source) OR (NOT led_state); 
-- LEDs are active LO

-- source LO = constant
-- source HI = PWM
---> source constant LO AND PWM channel --> LO

-- state LO = off
-- state HI = on
--> NOT state LO (HI) 
--> HI OR PWM/constant --> HI

begin

wb_adr <= wb_slave_i.ADR 	;
	
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
			wb_slave_o.DAT  <= (others => '0');
		
			
			if(wb_slave_i.WE ='1') then
				case adr  is				
					when x"00" =>	on_off	<= wb_slave_i.DAT  AND x"00000003";
					when x"04" =>	source	<= wb_slave_i.DAT  AND x"00000003";
				
					when others => null;
				end case;		
			else
				 -- set output to zero so all bits are driven
				case adr  is
					when x"00" =>	wb_slave_i.DAT <= on_off AND x"00000003";
					when x"04" =>	wb_slave_i.DAT <= source AND x"00000003";
					when others => null;
				end case;
			end if;	

        end if;    
    end if;
end process;
  
end behavioral;