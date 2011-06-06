-------------------------------------------------------------------------------
-- White Rabbit Switch / GSI BEL
-------------------------------------------------------------------------------
--
-- unit name: IPV4/UDP/Etherbone Header Package
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

---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;

use IEEE.numeric_std.all;

--! Additional library
library work;
use work.wishbone_package.all;
--! Additional packages    
--use work.XXX.all;


package EB_components_pkg is

component EB_CORE is 
port
(
	clk_i           	: in    std_logic;   --! clock input
	nRst_i				: in 	std_logic;
	
	slave_RX_stream_i	: in	wishbone_slave_in;
	slave_RX_stream_o	: out	wishbone_slave_out;

	master_TX_stream_i	: in	wishbone_master_in;
	master_TX_stream_o	: out	wishbone_master_out;
	
	master_IC_i			: in	wishbone_master_in;
	master_IC_o			: out	wishbone_master_out
	
);
end component;


component eb_2_wb_converter is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;

		--Eth MAC WB Streaming signals
		slave_RX_stream_i	: in	wishbone_slave_in;
		slave_RX_stream_o	: out	wishbone_slave_out;

		master_TX_stream_i	: in	wishbone_master_in;
		master_TX_stream_o	: out	wishbone_master_out;

		byte_count_rx_i			: in std_logic_vector(15 downto 0);
		
		--WB IC signals
		master_IC_i	: in	wishbone_master_in;
		master_IC_o	: out	wishbone_master_out

);
end component;

component EB_RX_CTRL is 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		
		RX_slave_o     : out   wb16_slave_out;	--! Wishbone master output lines
		RX_slave_i     : in    wb16_slave_in;    --!
		
		--Eth MAC WB Streaming signals
		wb_master_i			: in	wb32_master_in;
		wb_master_o			: out	wb32_master_out;

		reply_VLAN_o		: out	std_logic_vector(31 downto 0);
		reply_MAC_o			: out  std_logic_vector(47 downto 0);
		reply_IP_o			: out  std_logic_vector(31 downto 0);
		reply_PORT_o		: out  std_logic_vector(15 downto 0);

		TOL_o				: out std_logic_vector(15 downto 0);
		

		valid_o				: out std_logic
		
);
end component;



component EB_TX_CTRL is 
port(
		clk_i		: in std_logic;
		nRst_i		: in std_logic;
		
		--Eth MAC WB Streaming signals
		wb_slave_i	: in	wishbone_slave_in;
		wb_slave_o	: out	wishbone_slave_out;

		--TX_master_slv_o          : out   std_logic_vector(70 downto 0);	--! Wishbone master output lines
		--TX_master_slv_i          : in     std_logic_vector(35 downto 0);    --! 
		TX_master_o     : out   wb16_master_out;	--! Wishbone master output lines
		TX_master_i     : in     wb16_master_in;    --!
		

		reply_MAC_i			: in  std_logic_vector(47 downto 0);
		reply_IP_i			: in  std_logic_vector(31 downto 0);
		reply_PORT_i		: in  std_logic_vector(15 downto 0);

		TOL_i				: in std_logic_vector(15 downto 0);
		
		valid_i				: in std_logic
		
);
end component ;

component sipo_sreg_gen 
  generic(g_width_in : natural := 32; g_width_out : natural := 416);
   port(
  		d_i		: in	std_logic_vector(g_width_in -1 downto 0);
  		q_o		: out	std_logic_vector(g_width_out -1 downto 0);
  		clk_i	: in	std_logic;
  		nRST_i	: in 	std_logic;
  		en_i	: in 	std_logic;
  		clr_i	: in 	std_logic
  	);
  end component;

component piso_sreg_gen is 
generic(g_width_in : natural := 416; g_width_out : natural := 32);
 port(
		d_i		: in	std_logic_vector(g_width_in -1 downto 0);		--parallel in
		q_o		: out	std_logic_vector(g_width_out -1 downto 0);		--serial out
		clk_i	: in	std_logic;										--clock
		nRST_i	: in 	std_logic;
		en_i	: in 	std_logic;										--shift enable		
		ld_i	: in 	std_logic										--parallel load										
	);

end component;

component EB_checksum
  port(
  		clk_i	: in std_logic;
  		nRst_i	: in std_logic;
  		en_i	: in std_logic; 
  		data_i	: in std_logic_vector(15 downto 0);
  		done_o	: out std_logic;
  		sum_o	: out std_logic_vector(15 downto 0)
  );
  end component;
  
 
end EB_components_pkg;

package body EB_components_pkg is
 



----------------------------------------------------------------------------------

end package body;




