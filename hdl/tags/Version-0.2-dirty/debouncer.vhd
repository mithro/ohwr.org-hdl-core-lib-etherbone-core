--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity debouncer is
port(
	clk_i    		: in    std_logic;                                        --clock
 
	in_i			: in std_logic;
	out_o			: out std_logic
);	
end debouncer;

architecture behavioral of debouncer is

signal deb_reg : std_logic_vector(4 downto 0);
alias deb_reg_out : std_logic is deb_reg(deb_reg'left);
alias deb_reg_sh : std_logic_vector(3 downto 0) is deb_reg(deb_reg'left-1 downto deb_reg'right);

begin

debounce	:	process (clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
		deb_reg <= deb_reg_sh & in_i; 
	end if;
end process;

out_o <= deb_reg_out;
	


end architecture behavioral;   


