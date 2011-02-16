---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
--use work.EB_HDR_PKG.all;

entity g_wb_slave is 
generic(g_wb_data_width : natural := 32; g_wb_add_width : natural := 32; g_reg_count : natural := 3);
port
(
   
	clk_i	: in    std_logic;   --! byte clock, trigger on rising edge
	nRST_i  : in    std_logic;   --! reset, assert HI   

	data_i  : in std_logic_vector(g_wb_data_width-1 downto 0);
	data_o  : out std_logic_vector(g_wb_data_width-1 downto 0);
	addr_i	: in std_logic_vector(g_wb_add_width-1 downto 0);
   
	cyc_i	: in std_logic;
	stb_i	: in std_logic;
	we_i	: in std_logic;
	ack_o	: out std_logic
);
end g_wb_slave;


architecture behavioral of g_wb_slave is
    
subtype reg is std_logic_vector(g_wb_data_width-1 downto 0);
type regs is array (g_reg_count-1 downto 0) of reg;

signal registers : regs;
begin

p_main: process (clk_i)
begin
	if rising_edge(clk_i) then
       --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		ack_o <= '0';
		if (nRST_i = '0') then
			data_o <= (others => '0');
		else
			if(cyc_i = '1' AND stb_i = '1' AND (TO_INTEGER(unsigned(addr_i)) < g_reg_count)) then -- cycle valid and adress is mapped
				ack_o <= '1';
				data_o <= registers(TO_INTEGER(unsigned(addr_i)));
				if(we_i = '1') then
					registers(TO_INTEGER(unsigned(addr_i))) <= data_i;
				end if;				
			end if;
		end if;
	end if;                                             
end process;


end behavioral;