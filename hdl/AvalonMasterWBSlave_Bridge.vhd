-------------------------------------------------------------------------------
-- White Rabbit Switch / GSI BEL
-------------------------------------------------------------------------------
--
-- unit name: Avalon Master 2 Wishbone Slave Bridge (test stage)
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
-- dependencies: EB_HDR_PKG, piso_sreg_gen
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

---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
use work.wishbone_package.all;

entity test is 
generic(g_addr_width : natural := 32; g_data_width : natural := 32);
port
(
   csi_clk      		: 	in    std_logic;   --! byte clock, trigger on rising edge
   csi_n_rst    		: 	in    std_logic;   --! reset, assert HI   

   --WB Slave IOs
   -- WB_ACK_I				: 	in 		std_logic;
   -- WB_DATA_I			: 	in 		std_logic_vector(g_data_width-1 downto 0);	
   -- WB_STALL_I			: 	in 		std_logic;
   
   -- WB_STB_O				: 	out 	std_logic;
   -- WB_CYC_O				: 	out		std_logic;	
   -- WB_WE_O				: 	out		std_logic;	
   -- WB_ADDR_O			: 	out		std_logic_vector(g_addr_width-1 downto 0);	
   -- WB_DATA_O			: 	out		std_logic_vector(g_data_width-1 downto 0);	
   -- WB_SEL_O		 		: 	out		std_logic_vector(g_data_width/8-1 downto 0);	
   
	WB_slave_o	: out	wishbone_v4_slave;
	WB_slave_i	: in	wishbone_v4_slave;	
   
   --Avalon Master IOs
   AVS_SL_READ			: 	in	std_logic;	
   AVS_SL_WRITE			: 	in	std_logic;	
   AVS_SL_ADDRESS		: 	in	std_logic_vector(g_addr_width-1 downto 0);	
   AVS_SL_WRITEDATA		: 	in	std_logic_vector(g_data_width-1 downto 0);	
   AVS_SL_BYTEENABLE	: 	in	std_logic_vector(g_data_width/8-1 downto 0);		
   AVS_SL_ARBITERLOCK	:	in	std_logic;
   
   AVS_SL_WAITREQUEST	: 	out	std_logic;
   AVS_SL_READDATA		: 	out	std_logic_vector(g_data_width-1 downto 0);	
   AVS_SL_DATAAVAILABLE	: 	out	std_logic;	
   AVS_SL_READYFORDATA	: 	out	std_logic;	
   AVS_SL_READDATAVALID	: 	out	std_logic	
      
);
end test;

architecture behavioral of test is
  
begin



p_main: process (csi_clk)
begin
    if rising_edge(csi_clk) then
       --==========================================================================
       -- SYNC RESET                         
       --========================================================================== 
		if (csi_n_rst= '0') then
			WB_ADDR_O				<= (others => '0');
			WB_DATA_O				<= (others => '0');
			WB_SEL_O				<= (others => '0');
			AVS_SL_READDATA			<= (others => '0');	
			
			WB_STB_O				<= '0';
			WB_CYC_O				<= '0';
			WB_WE_O					<= '0';
			AVS_SL_WAITREQUEST		<= '0';
			AVS_SL_DATAAVAILABLE	<= '0';
			AVS_SL_READYFORDATA		<= '0';
			AVS_SL_READDATAVALID	<= '0';	
		else
			--BRIDGE: WISHBONE SLAVE SIDE OUT
			WB_STB_O 				<= AVS_SL_READ OR AVS_SL_WRITE;
			WB_CYC_O				<= AVS_SL_ARBITERLOCK OR AVS_SL_READ OR AVS_SL_WRITE;
			WB_WE_O					<= AVS_SL_WRITE;
			WB_ADDR_O				<= AVS_SL_ADDRESS;
			WB_DATA_O				<= AVS_SL_WRITEDATA;	
			WB_SEL_O				<= AVS_SL_BYTEENABLE;			 
			
			--BRIDGE: AVALON MASTER SIDE OUT
			AVS_SL_READDATA 		<= WB_DATA_I;	
			
			AVS_SL_DATAAVAILABLE	<= NOT WB_STALL_I;
			AVS_SL_READYFORDATA		<= NOT WB_STALL_I;
			AVS_SL_WAITREQUEST		<= WB_STALL_I; 
			AVS_SL_READDATAVALID 	<= WB_ACK_I;
							
			
			
			
		end if;
	end if;                                             
end process;


end behavioral; 
       
    
    
    


