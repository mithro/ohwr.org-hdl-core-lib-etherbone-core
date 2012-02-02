--! @file TB_eb_hw_test.vhd
--! @brief TB for first EB hardware implementation (single board)
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

--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wb32_package.all;
use work.wb16_package.all;

use work.vhdl_2008_workaround_pkg.all;


entity TB_eb_hw_test is
end TB_eb_hw_test;

architecture behavioral of TB_eb_hw_test is

component EB_HW_TEST is
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;
 
	alive_led_o		: out std_logic;
	leds_o			: out std_logic_vector(7 downto 0 );	 
	hex_switch_i		: in std_logic_vector(3 downto 0) := "0000"	 
);
end component EB_HW_TEST;

signal s_clk_i : std_logic := '0';
signal s_nRST_i : std_logic := '0';


signal stop_the_clock : std_logic := '0';
signal firstrun : boolean := true;
constant clock_period: time := 8 ns;


begin

WB_DEV : EB_HW_TEST
port map(
		clk_i	=> s_clk_i,
		nRst_i	=> s_nRst_i,
		
		leds_o     	=> open,	
		hex_switch_i   => x"8"

    );


clkGen : process
	
	begin 
		s_clk_i <= '0', '1' after clock_period / 2;
         wait for clock_period;
		 if(stop_the_clock = '1') then
			report "simulation end" severity failure;
			wait;
		end if;

    end process clkGen;

stim : process	
	 begin

		wait until rising_edge(s_clk_i);

		s_nRst_i <= '0';
		wait for clock_period;
		s_nRst_i <= '1';
		wait for clock_period;
		
		wait for 10 ms;
		stop_the_clock <= '1';
		wait;
	
end process stim;
	
end architecture behavioral;   


