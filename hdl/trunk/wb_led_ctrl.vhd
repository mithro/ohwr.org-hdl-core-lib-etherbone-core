--! @file wb_led_ctrl.vhd
--! @brief WB LED controller
--!
--! Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--! @bug No know bugs.
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
--------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.wb32_package.all;

entity wb_led_ctrl is 
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wb32_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wb32_slave_in;    --! 

		leds_o			: out	std_logic_vector(7 downto 0)
		
);

end wb_led_ctrl;


architecture behavioral of wb_led_ctrl is

component led_ctrl_pwm is 
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		
		led_power_i		: in std_logic_vector(31 downto 0) := x"00000001"; 
		led_ctrl_i		: in std_logic_vector(31 downto 0) := x"00000002"; 
		
		led_fix_i		: in std_logic_vector(31 downto 0) := (others => '0');  
		
		led_pwm_ctrl_i	: in std_logic_vector(31 downto 0) := x"00000001";  
		led_pwm_top_i	: in std_logic_vector(31 downto 0) := x"0000000F";  
		led_pwm_ocr_i	: in std_logic_vector(31 downto 0) := x"0000000B";  
		
		led_o			: out	std_logic
		
);
end component;

subtype dword is std_logic_vector(31 downto 0);
type mem is array (0 to 8*6-1) of dword ; 
signal my_mem : mem;  

signal 	wb_adr 		: natural;


begin

g1: FOR i IN 0 TO 7 GENERATE
  
led : led_ctrl_pwm
port map(clk_i    		=> clk_i ,                                 --clock
        nRST_i   		=> nRST_i,
		
		
		led_power_i		=> my_mem(i*6+0),
		led_ctrl_i		=> my_mem(i*6+1),
		
		led_fix_i		=> my_mem(i*6+2),
		
		led_pwm_ctrl_i	=> my_mem(i*6+3), 
		led_pwm_top_i	=> my_mem(i*6+4),
		led_pwm_ocr_i	=> my_mem(i*6+5), 
		
		led_o			=> leds_o(i)
		
);

END GENERATE;


wb_adr <= to_integer(unsigned(wb_slave_i.ADR(31 downto 2))); --divide by 4

	
wishbone_if	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then


			wb_slave_o	<=   (
								ACK   => '0',
								ERR   => '0',
								RTY   => '0',
								STALL => '0',
								DAT   => (others => '0'));
		else
            wb_slave_o.ACK <= wb_slave_i.CYC AND wb_slave_i.STB;
			wb_slave_o.DAT  <= (others => '1');
		
			if(wb_adr < 8*6) then	
				if(wb_slave_i.WE ='1') then
					my_mem(wb_adr) <= wb_slave_i.DAT;
				else
					wb_slave_o.DAT <= my_mem(wb_adr);
				end if;	
			end if;
        end if;    
    end if;
end process;
  
end behavioral;
