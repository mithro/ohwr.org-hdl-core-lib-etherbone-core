---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;

entity is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;

);
end entity;

architecture behavioral of is

constant c_width_int : integer := 24;

type st is (IDLE, ADDUP, CARRIES, FINALISE, OUTPUT);

signal state 		: st := IDLE;


begin


main: process(clk_i)
begin
	if rising_edge(clk_i) then

	   --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0') then

		else
			
		end if;
	end if;    
	
end process;

end behavioral;