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

entity wb_timer is 
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wishbone_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wishbone_slave_in;    --! 

		compmatchA_o		: out	std_logic;
		compmatchB_o		: out	std_logic
		
    );

end wb_timer;


architecture behavioral of wb_timer is

signal 		ctrl	  		: std_logic_vector(31 downto 0);	--x00
alias		ctrl_clear_cnt	: std_logic is ctrl(0);
alias		ctrl_start		: std_logic is ctrl(1);
alias		ctrl_stop		: std_logic is ctrl(2);
alias		ctrl_load_timer	: std_logic is ctrl(3);
alias		ctrl_load_ocrA	: std_logic is ctrl(4);
alias		ctrl_load_ocrB	: std_logic is ctrl(5);

signal 		stat	  		: std_logic_vector(31 downto 0);	--x04
alias		stat_running	: std_logic is stat(0);
alias 		stat_compA 	  	: std_logic is stat(1); 	
alias		stat_compB		: std_logic is stat(2);

signal 		timer  		: unsigned(g_cnt_width-1 downto 0);		--x08
signal 		timerbuff	: unsigned(g_cnt_width-1 downto 0); 	--x0C

signal 		ocrA 	  	: unsigned(g_cnt_width-1 downto 0); 	--x10
signal 		ocrB 	  	: unsigned(g_cnt_width-1 downto 0);		--x14
signal 		top   		: unsigned(g_cnt_width-1 downto 0);		--x18
signal 		prescaler 	: unsigned(g_cnt_width-1 downto 0); 	--x1C			

signal compmatchA		: std_logic;
signal compmatchB		: std_logic;

signal wb_adr : std_logic_vector(31 downto 0);

alias adr :  std_logic_vector(7 downto 0) is wb_adr(7 downto 0);


begin


	wb_adr <= wb_slave_i.ADR 	;
	compmatchA_o <= compmatchA;	
	compmatchB_o <= compmatchB;

wishbone_if	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then

			ocrA 		<= (others => '0');
			ocrB 		<= (others => '0');
			timer 		<= (others => '0');
			timerbuff	<= (others => '0');
			top 		<= (others => '0');
			stat 		<= (others => '0');
			ctrl		<= (others => '0');
			prescaler	<= (others => '0');
			compmatchA <= '0';		
			compmatchB <= '0';
			wb_slave_o	<=   (
												ACK   => '0',
												ERR   => '0',
												RTY   => '0',
												STALL => '0',
												DAT   => (others => '0'));
		else
            wb_slave_o.ACK <= wb_slave_i.CYC AND wb_slave_i.STB;
			wb_slave_o.DAT  <= (others => '0');
		
			
			if(wb_slave_i.WE ='1') then
				case adr  is				
					when x"00" =>	ctrl		<= wb_slave_i.DAT AND x"0000003F";
					when x"0C" =>	timerbuff	<= unsigned(wb_slave_i.DAT);
					when x"10" =>	ocrA		<= unsigned(wb_slave_i.DAT);
					when x"14" =>	ocrB		<= unsigned(wb_slave_i.DAT);
					when x"18" =>	top			<= unsigned(wb_slave_i.DAT);
					when x"1C" =>	prescaler	<= unsigned(wb_slave_i.DAT AND x"000000FF");
					
					when others => null;
				end case;		
			else
				 -- set output to zero so all bits are driven
				case adr  is
					when x"04" =>	wb_slave_o.DAT	<=	stat		AND x"00000007";
					when x"08" =>	wb_slave_o.DAT	<=	std_logic_vector(timer);
					when x"0C" =>	wb_slave_o.DAT	<=	std_logic_vector(timerbuff);
					when x"10" =>	wb_slave_o.DAT	<=	std_logic_vector(ocrA);
					when x"14" =>	wb_slave_o.DAT	<=	std_logic_vector(ocrB);
					when x"18" =>	wb_slave_o.DAT	<=	std_logic_vector(top);
					when x"1C" =>	wb_slave_o.DAT <= std_logic_vector(prescaler) AND x"000000FF";
					when others => null;
				end case;
			end if;	

        end if;    
    end if;
end process;
  
end behavioral;