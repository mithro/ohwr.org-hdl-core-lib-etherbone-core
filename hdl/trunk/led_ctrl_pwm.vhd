--! @file led_ctrl_pwm.vhd
--! @brief LED PWM brightness control
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
---------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity led_ctrl_pwm is 
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

end led_ctrl_pwm;


architecture behavioral of led_ctrl_pwm is

signal s_pwm_cnt 	: natural := 0;
-----------------------------------------------------------------
signal s_clk_div	: unsigned(1 downto 0) := (others => '0');
signal s_clk_div_reg: std_logic := '0';
signal s_clk_div_ovf: std_logic := '0';

signal s_pwm_val  	: std_logic := '0';
signal s_led_val  	: std_logic := '0';

begin



--0, fixed value, pwm
with led_ctrl_i(1 downto 0) select
s_led_val <= 	'0' when "00",
				led_fix_i(0) when "01",
				s_pwm_val when "10",
				'0' when others;
			
--switchable output inverter and on/off
led_o <= 	(s_led_val XOR led_ctrl_i(2)) AND led_power_i(0); 




clk_div	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then
			s_clk_div <= (others => '0');
		else
			s_clk_div_reg 	<= s_clk_div(s_clk_div'left);
			s_clk_div 		<= s_clk_div + 1;
			s_clk_div_ovf 	<= s_clk_div(s_clk_div'left) AND NOT s_clk_div_reg;
		end if;
    end if;
end process;

pwm	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        --reset counter
		if(nRSt_i = '0' OR led_pwm_ctrl_i(0) = '1') then
			s_pwm_cnt <= 0;
			s_pwm_val <= led_ctrl_i(3);
		else
			--start/stop
			if(led_pwm_ctrl_i(1) = '1') then
			
				if(s_clk_div_ovf = '1') then 
					s_pwm_cnt <= s_pwm_cnt + 1;
					
					if(s_pwm_cnt = to_integer(unsigned(led_pwm_ocr_i))) then
						s_pwm_val <= NOT s_pwm_val;
					end if;
					
					if(s_pwm_cnt >= to_integer(unsigned(led_pwm_top_i))) then
						s_pwm_cnt <= 0;
						s_pwm_val <= led_ctrl_i(3);
					end if;
				end if;	
			end if;
		end if;
    end if;
end process;
	

  
end behavioral;
