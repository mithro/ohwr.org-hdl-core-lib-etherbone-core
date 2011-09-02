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


