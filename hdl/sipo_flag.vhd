---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.vhdl_2008_workaround_pkg.all;

entity sipo_flag is
generic(g_width_IN : natural := 8; g_width_OUT  : natural := 32); 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		d_i					: in std_logic_vector(g_width_IN-1 downto 0);
		en_i				: in std_logic;
		clr_i				: in std_logic;
		
		q_o					: out std_logic_vector(g_width_OUT-1 downto 0);
		full_o				: out std_logic;
		empty_o				: out std_logic
);
end sipo_flag;




architecture behavioral of sipo_flag is

signal 	sh_reg 	: std_logic_vector(g_width_OUT-1 downto 0); -- length + 1 for flag
signal full : std_logic;
signal empty	: std_logic;

constant check_full : natural := maximum(0, g_width_OUT/g_width_IN-1);
signal cnt : unsigned(ld(g_width_OUT/g_width_IN) downto 0);
	
begin

q_o 	<= sh_reg(sh_reg'left downto 0);
full_o 	<= full;
empty_o <= empty;

  -- Your VHDL code defining the model goes here
  process (clk_i)
  begin
  	if (clk_i'event and clk_i = '1') then
  		if(nRSt_i = '0' OR clr_i = '1') then
			sh_reg 	<= (others => '0');
			full 	<= '0';
			empty	<= '1';
			cnt		<= (others => '0');
		else
			if(en_i = '1') then
				sh_reg 	<= sh_reg(g_width_OUT-1 - g_width_IN downto 0) & d_i;
				empty	<= '0';
				full 	<= '0';
				cnt <= cnt +1;
				
				if(cnt = check_full) then -- writing to last space
					full <= '1';
					cnt <= (others => '0');
				end if;
								
			end if;	
		end if;	
  	end if;
  end process;
  
end behavioral;