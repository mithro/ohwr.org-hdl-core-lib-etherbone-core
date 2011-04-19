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

entity av_wb_ram is 
generic(g_addr_width : natural := 32; g_data_width : natural := 32);
port
(
   csi_clk              : in     std_logic;   --! clock input
   csi_n_rst            : in     std_logic;   --! reset input, active low   
   
   --Avalon Slave IOs
   AVS_SL_READ          : in     std_logic;    
   AVS_SL_WRITE         : in     std_logic;    
   AVS_SL_ADDRESS       : in     std_logic_vector(g_addr_width-1 downto 0);    
   AVS_SL_WRITEDATA     : in     std_logic_vector(g_data_width-1 downto 0);    
   AVS_SL_BYTEENABLE    : in     std_logic_vector(g_data_width/8-1 downto 0);        
   AVS_SL_ARBITERLOCK   : in     std_logic;
   
   AVS_SL_WAITREQUEST   : out    std_logic;
   AVS_SL_READDATA      : out    std_logic_vector(g_data_width-1 downto 0);    
   AVS_SL_DATAAVAILABLE : out    std_logic;    
   AVS_SL_READYFORDATA  : out    std_logic;    
   AVS_SL_READDATAVALID : out    std_logic    
      
);
end av_wb_ram;

architecture behavioral of av_wb_ram is

component test is 
generic(g_addr_width : natural := 32; g_data_width : natural := 32);
port
(
   csi_clk              : in     std_logic;   --! clock input
   csi_n_rst            : in     std_logic;   --! reset input, active low   

   --Wishbone Master IOs
   wb_master_o          : out    wishbone_master_out;	--! Wishbone master output lines
   wb_master_i          : in     wishbone_master_in;    --! 
   
   --Avalon Slave IOs
   AVS_SL_READ          : in     std_logic;    
   AVS_SL_WRITE         : in     std_logic;    
   AVS_SL_ADDRESS       : in     std_logic_vector(g_addr_width-1 downto 0);    
   AVS_SL_WRITEDATA     : in     std_logic_vector(g_data_width-1 downto 0);    
   AVS_SL_BYTEENABLE    : in     std_logic_vector(g_data_width/8-1 downto 0);        
   AVS_SL_ARBITERLOCK   : in     std_logic;
   
   AVS_SL_WAITREQUEST   : out    std_logic;
   AVS_SL_READDATA      : out    std_logic_vector(g_data_width-1 downto 0);    
   AVS_SL_DATAAVAILABLE : out    std_logic;    
   AVS_SL_READYFORDATA  : out    std_logic;    
   AVS_SL_READDATAVALID : out    std_logic    
      
);
end component;

component alt_syncram_test IS
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (6 DOWNTO 0);
		byteena		: IN STD_LOGIC_VECTOR (3 DOWNTO 0) :=  (OTHERS => '1');
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		wren		: IN STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
	);
component alt_syncram_test;

s_wb_master_o : wishbone_master_out;
s_wb_master_i : wishbone_master_in;
s_ACK	: std_logic;

 
  
begin



end behavioral; 
       
    
    
    


