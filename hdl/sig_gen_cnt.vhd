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

		wave_p_o		: out std_logic;
		wave_n_o		: out std_logic			--inverted output
    );

end wave_gen;


architecture behavioral of wave_gen is

signal 		wb_out		: std_logic_vector(31 downto 0);


signal 		cnt 	 	: unsigned(g_cnt_width downto 0); 	-- width +1 to detect overflow

signal 		prescaler 	: unsigned(7 downto 0); 

 		

signal 		ocr 	  	: unsigned(g_cnt_width-1 downto 0); 
signal 		top   		: unsigned(g_cnt_width-1 downto 0);

signal 		ctrl	  		: std_logic_vector(31 downto 0);
alias		ctrl_clear_cnt	: std_logic_vector is ctrl(0);
alias		ctrl_start		: std_logic_vector is ctrl(1);
alias		ctrl_stop		: std_logic_vector is ctrl(2);
alias		ctrl_running	: std_logic_vector is ctrl(3);
alias 		ctrl_mode 	  	: std_logic_vector is ctrl(5 downto 4); 	
alias		ctrl_prescaler 	: std_logic_vector is ctrl(7 downto 6);
 --rd only


signal sel_mask		: std_logic_vector(31 downto 0);
alias  sel_mask_0	: std_logic_vector(7 downto 0) is sel_mask(7 downto 0);	
alias  sel_mask_1	: std_logic_vector(7 downto 0) is sel_mask(15 downto 8);	
alias  sel_mask_2	: std_logic_vector(7 downto 0) is sel_mask(23 downto 16);	
alias  sel_mask_3	: std_logic_vector(7 downto 0) is sel_mask(31 downto 24);		

signal wave : std_logic;

begin



clk_sel	

wave_p_o	<= wave;
wave_n_o	<= NOT wave;

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
