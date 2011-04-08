-------------------------------------------------------------------------------
-- White Rabbit Switch / GSI BEL
-------------------------------------------------------------------------------
--
-- unit name: Parallel-In/Serial-Out shift register
--
-- author: Mathias Kreider, m.kreider@gsi.de
--
-- date: $Date:: $:
--
-- version: $Rev:: $:
--
-- description: <file content, behaviour, purpose, special usage notes...>
-- <further description>
--
-- dependencies: <entity name>, ...
--
-- references: <reference one>
-- <reference two> ...
--
-- modified by: $Author:: $:
--
-------------------------------------------------------------------------------
-- last changes: <date> <initials> <log>
-- <extended description>
-------------------------------------------------------------------------------
-- TODO: <next thing to do>
-- <another thing to do>
--
-- This code is subject to GPL
-------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.wishbone_package.all;

entity wb_test_gen is 
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_master_slv_o          : out   std_logic_vector(70 downto 0);	--! Wishbone master output lines
		wb_master_slv_i          : in     std_logic_vector(35 downto 0)    --! 
		--wb_master_o     : out   wishbone_master_out;	--! Wishbone master output lines
		--wb_master_i     : in    wishbone_master_in    --!
		
		 

    );

end wb_test_gen;


architecture behavioral of wb_test_gen is

signal counter		: unsigned(31 downto 0);
signal stalled : std_logic;
signal  wb_master_o          : wishbone_master_out;	--! Wishbone master output lines
signal  wb_master_i          : wishbone_master_in;

begin

-- necessary to make QUARTUS SOPC builder see the WB intreface as conduit
wb_master_slv_o 	<=	TO_STD_LOGIC_VECTOR(wb_master_o);
wb_master_i			<=	TO_wishbone_master_in(wb_master_slv_i);


wb_master_o.DAT <= std_logic_vector(counter);

wishbone_if	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then

			counter <= (others => '0');
			
			wb_master_o.CYC   	<= '0';
			wb_master_o.STB   	<= '0';
			wb_master_o.WE   	<= '0';
			wb_master_o.ADR   	<= (others => '0');
			wb_master_o.SEL   	<= (others => '0');

		else
		
		wb_master_o.STB <= '0';
		
		
			if(counter < 10) then
				wb_master_o.CYC <= '1';
				if(wb_master_i.STALL ='1') then
					stalled <= '1';
				else
					wb_master_o.STB <= '1';
					
					if(stalled  = '1') then
						
						stalled  <= '0';
					else
						counter <= counter +1;
					end if;
				end if;	
			elsif(counter < 100) then
				wb_master_o.CYC <= '0';
				counter <= counter +1;
			else
				counter <= (others => '0');
			end if;
        end if;    
    end if;
end process;
  
end behavioral;