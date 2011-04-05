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

entity wave_gen is 
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_master_o     : out   wishbone_master_out;	--! Wishbone master output lines
		wb_master_i     : in    wishbone_master_in;    --! 

		compmatchA_o		: out	std_logic;
		compmatchB_o		: out	std_logic;
		
    );

end wave_gen;


architecture behavioral of wave_gen is

signal 		ctrl	  		: std_logic_vector(31 downto 0);	--x00
alias		ctrl_clear_cnt	: std_logic_vector is ctrl(0);
alias		ctrl_start		: std_logic_vector is ctrl(1);
alias		ctrl_stop		: std_logic_vector is ctrl(2);
alias		ctrl_load_timer	: std_logic_vector is ctrl(3);
alias		ctrl_load_ocrA	: std_logic_vector is ctrl(4);
alias		ctrl_load_ocrB	: std_logic_vector is ctrl(5);

signal 		stat	  		: std_logic_vector(31 downto 0);	--x04
alias		stat_running	: std_logic_vector is stat(0);
alias 		stat_compA 	  	: std_logic_vector is stat(1); 	
alias		stat_compB		: std_logic_vector is stat(2);

signal 		timer  		: unsigned(g_cnt_width-1 downto 0);		--x08
signal 		timerbuff	: unsigned(g_cnt_width-1 downto 0); 	--x0C

signal 		ocrA 	  	: unsigned(g_cnt_width-1 downto 0); 	--x10
signal 		ocrB 	  	: unsigned(g_cnt_width-1 downto 0);		--x14
signal 		top   		: unsigned(g_cnt_width-1 downto 0);		--x18
signal 		prescaler 	: unsigned(g_cnt_width-1 downto 0); 	--x1C			

signal compmatchA		: out	std_logic;
signal compmatchB

begin


-- PRESCALER UNIT
wavegen : process (clk_i)
begin
     if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0' OR ctrl_clr_cnt) then
			prescale8   <= (others => '0');
			prescale64  <= (others => '0');
			prescale256 <= (others => '0');
		else
			if(running <= '1') then 
				prescale8 <= 
			end if;


			
			
-- WAVE GENERATOR --------------------------------------------------------------------------		

wavegen : process (clk_i)
begin
     if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then
			cnt 		<= (others => '0');
wave 		<= '0';	
        elsif(ctrl_clr_cnt = '1') then      
			cnt 		<= top;
			wave 		<= '0';
		else
		
			if(ctrl_stop = '1')	then
				running <= '0';
			elsif(start = '1')
				running <= '1';
			end if;
			
			if(cnt(cnt'left) = '1') 
			
			if(cnt = ocr) then
			
			wave	<=  	
					
	end if;

	
end process wavegen;		
		


wishbone_if	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then

			ocr 		<= (others => '0');
			top 		<= (others => '0');
			ctrl		<= (others => '0');
			wb_out		<= (others => '0');
				
        else
            wb_master_o.ACK <= wb_master_i.CYC AND wb_master_i.STB;
			
			--clear CTRL wr only bits
			ctrl_clear_cnt	<= '0';
			ctrl_start		<= '0';
			ctrl_stop		<= '0';
			
			if(WE ='1')
				case wb_master_i.ADR is				
					when 0 =>	ctrl( 	<= wb_in;
					when 1 =>	ocr		<= wb_in;
					when 2 =>	top		<= wb_in;
					when others => null;
				end case;		
			else
				wb_out  <= (others => '0'); -- set output to zero so all bits are driven
				case wb_master_i.ADR is
					when 0 =>	wb_out <= ctrl AND sel_mask;
					when 1 =>   wb_out <= ocr  AND sel_mask;
					when 2 =>   wb_out <= top  AND sel_mask;
					when 3 =>   wb_out <= cnt  AND sel_mask;
					when others => null;
				end case;
			end if;	

        end if;    
    end if;
end process;
  
end behavioral;