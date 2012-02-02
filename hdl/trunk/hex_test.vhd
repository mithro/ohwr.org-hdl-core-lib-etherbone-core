--! @file hex_test.vhd
--! @brief just a test, to be thrown away
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

--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity hex_test is
port(
	clk_i    		: in    std_logic;                                        --clock
 
	in_i			: in std_logic_vector(3 downto 0);
	out_o			: out std_logic_vector(3 downto 0)
);	
end hex_test;

architecture behavioral of hex_test is

component debouncer is
port(
	clk_i    		: in    std_logic;                                        --clock
 
	in_i			: in std_logic;
	out_o			: out std_logic
);	
end component debouncer;

signal s_out : std_logic_vector(3 downto 0);

begin

g1: FOR i IN 0 TO 3 GENERATE
  
deb : debouncer
port map(
		clk_i	=> clk_i,
		
		in_i	=> in_i(i),
		out_o	=> s_out(i)
    );

END GENERATE;


check:	process (clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
		out_o <= NOT (s_out);
	end if;
end process;


	


end architecture behavioral;   


