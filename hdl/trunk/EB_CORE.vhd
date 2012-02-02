--! @file EB_CORE.vhd
--! @brief Top file for EtherBone core
--!
--! Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--! @bug No know bugs.
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
--use work.EB_components_pkg.all;
use work.wb32_package.all;
use work.wb16_package.all;


entity EB_CORE is 
generic(g_master_slave : natural := 0);
port
(
	clk_i           	: in    std_logic;   --! clock input
	nRst_i				: in 	std_logic;
	
	-- slave RX streaming IF -------------------------------------
	slave_RX_CYC_i		: in 	std_logic;						--
	slave_RX_STB_i		: in 	std_logic;						--
	slave_RX_DAT_i		: in 	std_logic_vector(15 downto 0);	--	
	slave_RX_WE_i		: in 	std_logic;	
	slave_RX_STALL_o	: out 	std_logic;						--						
	slave_RX_ERR_o		: out 	std_logic;						--
	slave_RX_ACK_o		: out 	std_logic;						--
	--------------------------------------------------------------
	
	-- master TX streaming IF ------------------------------------
	master_TX_CYC_o		: out 	std_logic;						--
	master_TX_STB_o		: out 	std_logic;						--
	master_TX_WE_o		: out 	std_logic;	
	master_TX_DAT_o		: out 	std_logic_vector(15 downto 0);	--	
	master_TX_STALL_i	: in 	std_logic;						--						
	master_TX_ERR_i		: in 	std_logic;						--
	master_TX_ACK_i		: in 	std_logic;						--
	--------------------------------------------------------------
	debug_TX_TOL_o			: out std_logic_vector(15 downto 0);
	hex_switch_i		: in std_logic_vector(3 downto 0);
	-- master IC IF ----------------------------------------------
	WB_master_i			: in	wb32_master_in;
	WB_master_o			: out	wb32_master_out
	--------------------------------------------------------------
	
);
end EB_CORE;

architecture behavioral of EB_CORE is

signal DEBUG_sink1_valid : std_logic;
signal DEBUG_sink23_valid : std_logic;

signal DEBUG_WB_master_o 		: wb32_master_out;



-- TX CTRL  <-> EBCORE signals

signal EB_2_TXCTRL_wb_slave			: wb32_slave_in;
signal TXCTRL_2_EB_wb_slave 		: wb32_slave_out;



signal EB_2_RXCTRL_wb_master		: wb32_master_in;
signal RXCTRL_2_EB_wb_master 		: wb32_master_out;

-- RX CTRL <-> TXCTRL signals
signal RXCTRL_2_TXCTRL_reply_MAC 	: std_logic_vector(47 downto 0);
signal RXCTRL_2_TXCTRL_reply_IP 	: std_logic_vector(31 downto 0);
signal RXCTRL_2_TXCTRL_reply_PORT 	: std_logic_vector(15 downto 0);
signal RXCTRL_2_TXCTRL_TOL 			: std_logic_vector(15 downto 0);
signal RXCTRL_2_TXCTRL_valid 		: std_logic;

--EB <-> TXCTRL
signal EB_2_TXCTRL_wb_master		: wb32_master_out;
signal TXCTRL_2_EB_wb_master 		: wb32_master_in;

--EB <-> RXCTRL
signal EB_2_RXCTRL_wb_slave			: wb32_slave_out;
signal RXCTRL_2_EB_wb_slave 		: wb32_slave_in;

signal	EB_RX_i	:		wb16_slave_in;
signal	EB_RX_o	:		wb16_slave_out;

signal	EB_TX_i	:		wb16_master_in;
signal	EB_TX_o	:		wb16_master_out;

component binary_sink is
generic(filename : string := "123.pcap";  wordsize : natural := 64; endian : natural := 0);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	rdy_o			: out  	std_logic;

	sample_i		: in   	std_logic;
	valid_i			: in	std_logic;	
	data_i			: in	std_logic_vector(wordsize-1 downto 0)
);	
end component;



component EB_TX_CTRL is 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		--Eth MAC WB Streaming signals
		wb_slave_i			: in	wb32_slave_in;
		wb_slave_o			: out	wb32_slave_out;

		TX_master_o     	: out   wb16_master_out;	--! Wishbone master output lines
		TX_master_i     	: in    wb16_master_in;    --!
		

		
		reply_MAC_i			: in  std_logic_vector(47 downto 0);
		reply_IP_i			: in  std_logic_vector(31 downto 0);
		reply_PORT_i		: in  std_logic_vector(15 downto 0);

		TOL_i				: in std_logic_vector(15 downto 0);
		
		valid_i				: in std_logic
		
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

component eb_2_wb_converter is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;

		--Eth MAC WB Streaming signals
		EB_RX_i	: in	wb32_slave_in;
		EB_RX_o	: out	wb32_slave_out;

		EB_TX_i	: in	wb32_master_in;
		EB_TX_o	: out	wb32_master_out;

		byte_count_rx_i			: in std_logic_vector(15 downto 0);
		
		--WB IC signals
		WB_master_i	: in	wb32_master_in;
		WB_master_o	: out	wb32_master_out

);
end component;

component eb_mini_master is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;

		--Eth MAC WB Streaming signals
		EB_RX_i	: in	wb32_slave_in;
		EB_RX_o	: out	wb32_slave_out;

		EB_TX_i	: in	wb32_master_in;
		EB_TX_o	: out	wb32_master_out;

		byte_count_rx_i			: in std_logic_vector(15 downto 0);
		
		dst_MAC_o			: out  std_logic_vector(47 downto 0);
		dst_IP_o			: out  std_logic_vector(31 downto 0);
		dst_PORT_o			: out  std_logic_vector(15 downto 0);

		TOL_o				: out std_logic_vector(15 downto 0);
		hex_switch_i		: in std_logic_vector(3 downto 0);

		valid_o				: out std_logic

);
end component;


 begin
 
 debug_TX_TOL_o <= RXCTRL_2_TXCTRL_TOL;
 
 


-- file_sink1: binary_sink generic map ( filename => "Eb_RX_data.dat",
                                 -- wordsize =>   32,
                                 -- endian   =>  0)
                      -- port map ( clk_i    => clk_i,
                                 -- nRST_i   => nRST_i,
                                 -- rdy_o    => open,
                                 -- sample_i => RXCTRL_2_EB_wb_master.CYC,
                                 -- valid_i  => DEBUG_sink1_valid,
                                 -- data_i   => RXCTRL_2_EB_wb_master.DAT );							 
 
-- file_sink2: binary_sink generic map ( filename => "Eb_WB_data_o.dat",
                                 -- wordsize =>   32,
                                 -- endian   =>  0)
                      -- port map ( clk_i    => clk_i,
                                 -- nRST_i   => nRST_i,
                                 -- rdy_o    => open,
                                 -- sample_i => DEBUG_WB_master_o.CYC,
                                 -- valid_i  => DEBUG_sink23_valid,
                                 -- data_i   => DEBUG_WB_master_o.DAT );							 
 
 -- file_sink3: binary_sink generic map ( filename => "Eb_WB_addr.dat",
                                 -- wordsize =>   32,
                                 -- endian   =>  0)
                      -- port map ( clk_i    => clk_i,
                                 -- nRST_i   => nRST_i,
                                 -- rdy_o    => open,
                                 -- sample_i => DEBUG_WB_master_o.CYC,
                                 -- valid_i  => DEBUG_sink23_valid,
                                 -- data_i   => DEBUG_WB_master_o.ADR );	
 
  -- file_sink4: binary_sink generic map ( filename => "Eb_WB_data_i.dat",
                                 -- wordsize =>   32,
                                 -- endian   =>  0)
                      -- port map ( clk_i    => clk_i,
                                 -- nRST_i   => nRST_i,
                                 -- rdy_o    => open,
                                 -- sample_i => DEBUG_WB_master_o.CYC,
                                 -- valid_i  =>  WB_master_i.ACK,
                                 -- data_i   => WB_master_i.DAT );	
 

 DEBUG_sink1_valid <= (RXCTRL_2_EB_wb_master.STB AND NOT EB_2_RXCTRL_wb_slave.STALL);
 DEBUG_sink23_valid <=	 (DEBUG_WB_master_o.STB AND NOT  WB_master_i.STALL);

  
 -- EB type conversions for WB daisychain
EB_2_TXCTRL_wb_slave 		<= wb32_slave_in(EB_2_TXCTRL_wb_master);
TXCTRL_2_EB_wb_master 		<= wb32_master_in(TXCTRL_2_EB_wb_slave);

EB_2_RXCTRL_wb_master		<= wb32_master_in(EB_2_RXCTRL_wb_slave);
RXCTRL_2_EB_wb_slave 		<= wb32_slave_in(RXCTRL_2_EB_wb_master);

-- assign records to individual bus signals.
-- slave RX
EB_RX_i.CYC 		<= slave_RX_CYC_i;
EB_RX_i.STB 		<= slave_RX_STB_i;
EB_RX_i.DAT 		<= slave_RX_DAT_i;
EB_RX_i.WE 		<= slave_RX_WE_i;
slave_RX_STALL_o 			<= EB_RX_o.STALL;						
slave_RX_ERR_o 				<= EB_RX_o.ERR;
slave_RX_ACK_o 				<= EB_RX_o.ACK;

-- master TX
master_TX_CYC_o				<= EB_TX_o.CYC;
master_TX_STB_o				<= EB_TX_o.STB;
master_TX_DAT_o				<= EB_TX_o.DAT;
master_TX_WE_o				<= EB_TX_o.WE;
EB_TX_i.STALL 	<= master_TX_STALL_i;						
EB_TX_i.ERR 		<= master_TX_ERR_i;
EB_TX_i.ACK 		<= master_TX_ACK_i;

master : if(g_master_slave = 1) generate

	 minimaster : eb_mini_master
	port map(
		   --general
		clk_i	=> clk_i,
		nRst_i	=> nRst_i,

		--Eth MAC WB Streaming signals
		EB_RX_i	=> RXCTRL_2_EB_wb_slave,
		EB_RX_o	=> EB_2_RXCTRL_wb_slave,

		EB_TX_i	=> TXCTRL_2_EB_wb_master,
		EB_TX_o	=> EB_2_TXCTRL_wb_master,

		byte_count_rx_i		=> RXCTRL_2_TXCTRL_TOL,

		dst_MAC_o			=> RXCTRL_2_TXCTRL_reply_MAC,
		dst_IP_o			=> RXCTRL_2_TXCTRL_reply_IP,
		dst_PORT_o			=> RXCTRL_2_TXCTRL_reply_PORT,
		TOL_o				=> RXCTRL_2_TXCTRL_TOL,
		hex_switch_i		=> hex_switch_i,
		valid_o				=> RXCTRL_2_TXCTRL_valid
	);  

	 TXCTRL : EB_TX_CTRL
	port map
	(
			clk_i             => clk_i,
			nRST_i            => nRst_i, 
			
			--Eth MAC WB Streaming signals
			wb_slave_i	=> EB_2_TXCTRL_wb_slave,
			wb_slave_o	=> TXCTRL_2_EB_wb_slave,

			TX_master_o     =>	EB_TX_o,
			TX_master_i     =>  EB_TX_i,  --!
			
			reply_MAC_i			=> RXCTRL_2_TXCTRL_reply_MAC, 
			reply_IP_i			=> RXCTRL_2_TXCTRL_reply_IP,
			reply_PORT_i		=> RXCTRL_2_TXCTRL_reply_PORT,

			TOL_i				=> RXCTRL_2_TXCTRL_TOL,
			
			valid_i				=> RXCTRL_2_TXCTRL_valid
			
	);


	RXCTRL: EB_RX_CTRL port map ( clk_i          => clk_i,
								 nRst_i         => nRst_i,
								 wb_master_i    => EB_2_RXCTRL_wb_master,
								 wb_master_o    => RXCTRL_2_EB_wb_master,
									 
								 RX_slave_o => EB_RX_o,
								 RX_slave_i => EB_RX_i,
								 
								 reply_MAC_o    => open,
								 reply_IP_o     => open,
								 reply_PORT_o   => open,
								 TOL_o          => open,
								 valid_o        => open);
								 
	WB_master_o <= DEBUG_WB_master_o;

end generate;

slave : if(g_master_slave = 0) generate
	 
	  TXCTRL : EB_TX_CTRL
	port map
	(
			clk_i             => clk_i,
			nRST_i            => nRst_i, 
			
			--Eth MAC WB Streaming signals
			wb_slave_i	=> EB_2_TXCTRL_wb_slave,
			wb_slave_o	=> TXCTRL_2_EB_wb_slave,

			TX_master_o     =>	EB_TX_o,
			TX_master_i     =>  EB_TX_i,  --!
			
			reply_MAC_i			=> RXCTRL_2_TXCTRL_reply_MAC, 
			reply_IP_i			=> RXCTRL_2_TXCTRL_reply_IP,
			reply_PORT_i		=> RXCTRL_2_TXCTRL_reply_PORT,

			TOL_i				=> RXCTRL_2_TXCTRL_TOL,
			
			valid_i				=> RXCTRL_2_TXCTRL_valid
			
	);


	RXCTRL: EB_RX_CTRL port map ( clk_i          => clk_i,
								 nRst_i         => nRst_i,
								 wb_master_i    => EB_2_RXCTRL_wb_master,
								 wb_master_o    => RXCTRL_2_EB_wb_master,
									 
								 RX_slave_o => EB_RX_o,
								 RX_slave_i => EB_RX_i,
								 
								 reply_MAC_o    => RXCTRL_2_TXCTRL_reply_MAC,
								 reply_IP_o     => RXCTRL_2_TXCTRL_reply_IP,
								 reply_PORT_o   => RXCTRL_2_TXCTRL_reply_PORT,
								 TOL_o          => RXCTRL_2_TXCTRL_TOL,
								 valid_o        => RXCTRL_2_TXCTRL_valid);
								 
	WB_master_o <= DEBUG_WB_master_o;

	 
	 EB : eb_2_wb_converter
	port map(
		   --general
		clk_i	=> clk_i,
		nRst_i	=> nRst_i,

		--Eth MAC WB Streaming signals
		EB_RX_i	=> RXCTRL_2_EB_wb_slave,
		EB_RX_o	=> EB_2_RXCTRL_wb_slave,

		EB_TX_i	=> TXCTRL_2_EB_wb_master,
		EB_TX_o	=> EB_2_TXCTRL_wb_master,

		byte_count_rx_i		=> RXCTRL_2_TXCTRL_TOL,

		
		--WB IC signals
		WB_master_i			=> WB_master_i,
		WB_master_o			=> DEBUG_WB_master_o
	);  
 
end generate;

end behavioral; 
