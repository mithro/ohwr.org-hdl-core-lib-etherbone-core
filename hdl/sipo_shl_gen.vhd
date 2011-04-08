
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sipo_sreg_gen is 
generic(g_width_in : natural := 32; g_width_out : natural := 416);
 port(
		d_i		: in	std_logic_vector(g_width_in -1 downto 0);		--serial in
		q_o		: out	std_logic_vector(g_width_out -1 downto 0);		--parallel out
		clk_i	: in	std_logic;										--clock
		nRST_i	: in 	std_logic;										--reset
		en_i	: in 	std_logic;										--shift enable		
		clr_i	: in 	std_logic										--clear
	);

end sipo_sreg_gen;


architecture left_shift of sipo_sreg_gen is

signal reg : std_logic_vector(g_width_out -1 downto 0);

begin

q_o <= reg;

  -- Your VHDL code defining the model goes here
  process (clk_i)
  begin
  	-- Define a 4-bit d-filp-flop
  	if (clk_i'event and clk_i = '1') then
  		if(nRSt_i = '0' OR clr_i = '1') then
			reg <= (others => '0');
		else
			if(en_i = '1') then
				reg <= reg(g_width_out - g_width_in - 1 downto g_width_in) & d_i;
			end if;	
		end if;	
  	end if;
  end process;
  
end left_shift;
