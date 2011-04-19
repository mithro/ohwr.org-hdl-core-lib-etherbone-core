
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity piso_sreg_gen is 
generic(g_width_in : natural := 416; g_width_out : natural := 32);
 port(
		d_i		: in	std_logic_vector(g_width_in -1 downto 0);		--parallel in
		q_o		: out	std_logic_vector(g_width_out -1 downto 0);		--serial out
		clk_i	: in	std_logic;										--clock
		nRST_i	: in 	std_logic;
		en_i	: in 	std_logic;										--shift enable		
		ld_i	: in 	std_logic										--parallel load										
	);

end piso_sreg_gen;


architecture right_shift of piso_sreg_gen is

signal reg : std_logic_vector(g_width_in -1 downto 0);
constant  zero_insert : std_logic_vector(g_width_out-1 downto 0) := (others => '0');

begin

q_o <= reg(g_width_in -1 downto g_width_in - g_width_out);

  -- Your VHDL code defining the model goes here
  process (clk_i)
  begin
  	-- Define a 4-bit d-filp-flop
  	if (clk_i'event and clk_i = '1') then
  		if(nRSt_i = '0') then
			reg <= (others => '0');
		else
			if(ld_i = '1') then
				reg <= d_i;		
			elsif(en_i = '1') then
				reg <= reg(g_width_in - g_width_out -1 downto 0) & zero_insert;
				--reg <= reg(g_width_out - g_width_in - 1 downto g_width_in) & d_i;
			end if;	
		end if;	
  	end if;
  end process;
  
end right_shift;
