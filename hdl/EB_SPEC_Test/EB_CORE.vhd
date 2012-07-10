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
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;


entity EB_CORE is 
generic(g_master_slave : STRING := "SLAVE";
        g_sdb_address : std_logic_vector(63 downto 0));
port
(
	clk_i           	: in    std_logic;   --! clock input
	nRst_i				: in 	std_logic;
	
	-- EB streaming sink -----------------------------------------
	snk_i		: in 	t_wrf_sink_in;						
	snk_o		: out	t_wrf_sink_out;						
	--------------------------------------------------------------
	
	-- EB streaming source ---------------------------------------
	src_o		: out t_wrf_source_out;					
	src_i		: in  t_wrf_source_in;						
	--------------------------------------------------------------

   -- WB slave - Cfg IF -----------------------------------------
	cfg_slave_o : out t_wishbone_slave_out;
   cfg_slave_i : in  t_wishbone_slave_in;
	
 	-- WB master - Bus IF ----------------------------------------
	master_o : out t_wishbone_master_out;
   master_i : in  t_wishbone_master_in
	--------------------------------------------------------------
	
);
end EB_CORE;






architecture behavioral of EB_CORE is

signal s_status_en : std_logic;
signal s_status_clr : std_logic;

signal DEBUG_WB_master_o 		: wb32_master_out;
signal WB_master_i			     : wb32_master_in;


-- int eb if to cfg space
signal eb_2_CFG_slave			: wb32_slave_in;
signal CFG_2_eb_slave 		: wb32_slave_out;


-- ext if to cfg space
signal EXT_2_CFG_slave			: wb32_slave_in;
signal CFG_2_EXT_slave 		: wb32_slave_out;

signal CFG_MY_MAC : std_logic_vector(6*8-1 downto 0);
signal CFG_MY_IP : std_logic_vector(4*8-1 downto 0);
signal CFG_MY_PORT : std_logic_vector(2*8-1 downto 0);


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
signal RXCTRL_2_CORE_LEN 			: std_logic_vector(15 downto 0);
signal RXCTRL_2_TXCTRL_valid 		: std_logic;

--EB <-> TXCTRL
signal EB_2_TXCTRL_wb_master		: wb32_master_out;
signal TXCTRL_2_EB_wb_master 		: wb32_master_in;

--EB <-> RXCTRL
signal EB_2_RXCTRL_wb_slave			: wb32_slave_out;
signal RXCTRL_2_EB_wb_slave 		: wb32_slave_in;

signal	EB_RX_i	:		t_wrf_sink_in;
signal	EB_RX_o	:		t_wrf_sink_out;

signal	EB_TX_i	:		t_wrf_source_in;
signal	EB_TX_o	:		t_wrf_source_out;

signal EB_2_TXCTRL_silent : std_logic;


component EB_TX_CTRL is
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		--Eth MAC WB Streaming signals
		wb_slave_i			: in	wb32_slave_in;
		wb_slave_o			: out	wb32_slave_out;


    		src_i : in  t_wrf_source_in;
    		src_o : out t_wrf_source_out;

	
		reply_MAC_i  : in std_logic_vector(6*8-1 downto 0);
    		reply_IP_i   : in std_logic_vector(4*8-1 downto 0);
		reply_Port_i : in std_logic_vector(2*8-1 downto 0);

		
		TOL_i        : in std_logic_vector(2*8-1 downto 0);
		payload_len_i : in std_logic_vector(2*8-1 downto 0);

		my_mac_i  : in std_logic_vector(6*8-1 downto 0);
		my_vlan_i : in std_logic_vector(2*8-1 downto 0); 
		my_ip_i   : in std_logic_vector(4*8-1 downto 0);
		my_port_i : in std_logic_vector(2*8-1 downto 0);

		
		silent_i			: in std_logic;
		valid_i				: in std_logic
		
);
end component;

component EB_RX_CTRL is
 port (
    clk_i   : in std_logic;
    nRst_i : in std_logic;

    -- Wishbone Fabric Interface I/O
    snk_i : in  t_wrf_sink_in;
    snk_o : out t_wrf_sink_out;

    --Eth MAC WB Streaming signals
    wb_master_i : in  wb32_master_in;
    wb_master_o : out wb32_master_out;

    reply_MAC_o  : out std_logic_vector(6*8-1 downto 0);
    reply_IP_o   : out std_logic_vector(4*8-1 downto 0);
    reply_Port_o : out std_logic_vector(2*8-1 downto 0);
    TOL_o        : out std_logic_vector(2*8-1 downto 0);
    payload_len_o : out std_logic_vector(2*8-1 downto 0);
    
    my_mac_i  : in std_logic_vector(6*8-1 downto 0);
    my_vlan_i : in std_logic_vector(2*8-1 downto 0); 
    my_ip_i   : in std_logic_vector(4*8-1 downto 0);
    my_port_i : in std_logic_vector(2*8-1 downto 0);
    
    valid_o : out std_logic

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
		TX_silent_o : out std_logic;

		byte_count_rx_i			: in std_logic_vector(15 downto 0);
		
		--config signals
		config_master_i     : in  wb32_master_in;                --! WB V4 interface to WB interconnect/device(s)
		config_master_o     : out wb32_master_out;                --! WB V4 interface to WB interconnect/device(s)
		
		
		--WB IC signals
		WB_master_i	: in	wb32_master_in;
		WB_master_o	: out	wb32_master_out

);
end component;

component eb_config is 
 generic(
   g_sdb_address : std_logic_vector(63 downto 0));
 port(
		clk_i    		     : in std_logic;                                        --clock
    nRST_i       		 : in std_logic;
		status_i		      : in std_logic;
		status_en		     : in	std_logic;
		status_clr		    : in	std_logic;
		
		my_mac_o  : out std_logic_vector(6*8-1 downto 0);
		my_ip_o   : out std_logic_vector(4*8-1 downto 0);
		my_port_o   : out std_logic_vector(2*8-1 downto 0);
		
		local_slave_o   : out wb32_slave_out;
		local_slave_i   : in wb32_slave_in;	--! local Wishbone master lines
				
		eb_slave_o      : out wb32_slave_out;	--! EB Wishbone slave lines
		eb_slave_i      : in  wb32_slave_in
    );
end component;





 begin
 

 





  
 -- EB type conversions for WB daisychain
EB_2_TXCTRL_wb_slave 		<= wb32_slave_in(EB_2_TXCTRL_wb_master);
TXCTRL_2_EB_wb_master 		<= wb32_master_in(TXCTRL_2_EB_wb_slave);

EB_2_RXCTRL_wb_master		<= wb32_master_in(EB_2_RXCTRL_wb_slave);
RXCTRL_2_EB_wb_slave 		<= wb32_slave_in(RXCTRL_2_EB_wb_master);

-- assign records to individual bus signals.


master_o.cyc  <= DEBUG_WB_master_o.CYC;
master_o.we   <= DEBUG_WB_master_o.WE;
master_o.stb  <= DEBUG_WB_master_o.STB;
master_o.sel  <= DEBUG_WB_master_o.SEL;
master_o.adr  <= DEBUG_WB_master_o.ADR;
master_o.dat  <= DEBUG_WB_master_o.DAT;
WB_master_i.DAT   <= master_i.dat;
WB_master_i.STALL   <= master_i.stall;
WB_master_i.ACK   <= master_i.ack;
WB_master_i.ERR <= master_i.err;


-- ext interface to cfg space
EXT_2_CFG_slave.CYC <= cfg_slave_i.cyc;
EXT_2_CFG_slave.STB <= cfg_slave_i.stb; 
EXT_2_CFG_slave.WE  <= cfg_slave_i.we;
EXT_2_CFG_slave.SEL <= cfg_slave_i.sel;
EXT_2_CFG_slave.ADR <= cfg_slave_i.adr;
EXT_2_CFG_slave.DAT <= cfg_slave_i.dat; 
cfg_slave_o.ack     <= CFG_2_EXT_slave.ACK;
cfg_slave_o.stall   <= CFG_2_EXT_slave.STALL;
cfg_slave_o.err     <= CFG_2_EXT_slave.ERR; 
cfg_slave_o.dat     <= CFG_2_EXT_slave.DAT;
	 
	  TXCTRL : EB_TX_CTRL
	port map
	(
			clk_i             => clk_i,
			nRST_i            => nRst_i, 
			
			--Eth MAC WB Streaming signals
			wb_slave_i	=> EB_2_TXCTRL_wb_slave,
			wb_slave_o	=> TXCTRL_2_EB_wb_slave,

			src_o     =>	src_o,
			src_i     =>  src_i,  --!
			
			reply_MAC_i			=> RXCTRL_2_TXCTRL_reply_MAC, 
			reply_IP_i			=> RXCTRL_2_TXCTRL_reply_IP,
			reply_PORT_i		=> RXCTRL_2_TXCTRL_reply_PORT,

			TOL_i				=> RXCTRL_2_TXCTRL_TOL,
			payload_len_i =>  RXCTRL_2_CORE_LEN,
			
			my_mac_i  => CFG_MY_MAC,
		            my_ip_i   => CFG_MY_IP,
		            my_port_i => CFG_MY_PORT,
		            my_vlan_i => (others => '0'),
		        silent_i => EB_2_TXCTRL_silent,    
			valid_i				=> RXCTRL_2_TXCTRL_valid
			
	);


	RXCTRL: EB_RX_CTRL 
	port map ( clk_i          => clk_i,
								 nRst_i         => nRst_i,
								 wb_master_i    => EB_2_RXCTRL_wb_master,
								 wb_master_o    => RXCTRL_2_EB_wb_master,
									 
								 snk_o => snk_o,
								 snk_i => snk_i,
								 
								 reply_MAC_o    => RXCTRL_2_TXCTRL_reply_MAC,
								 reply_IP_o     => RXCTRL_2_TXCTRL_reply_IP,
								 reply_PORT_o   => RXCTRL_2_TXCTRL_reply_PORT,
								 TOL_o          => RXCTRL_2_TXCTRL_TOL,
								 payload_len_o =>  RXCTRL_2_CORE_LEN,
								 my_mac_i  => CFG_MY_MAC,
		            my_ip_i   => CFG_MY_IP,
		            my_port_i => CFG_MY_PORT,
		            my_vlan_i => (others => '0'),
								 valid_o        => RXCTRL_2_TXCTRL_valid);
								 
	

	 
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
		TX_silent_o => EB_2_TXCTRL_silent,
		byte_count_rx_i		=> RXCTRL_2_CORE_LEN,

		config_master_i => CFG_2_eb_slave,              
		config_master_o => eb_2_CFG_slave,
		
		--WB IC signals
		WB_master_i			=> WB_master_i,
		WB_master_o			=> DEBUG_WB_master_o
	);  
 
 
 s_status_en <= WB_master_i.ACK OR WB_master_i.ERR;
 s_status_clr <= NOT DEBUG_WB_master_o.CYC;
 
 cfg_space : eb_config
 generic map(
   g_sdb_address => g_sdb_address)
 port map(
		   --general
		clk_i	=> clk_i,
		nRst_i	=> nRst_i,

		status_i          => WB_master_i.ERR,
		status_en         => s_status_en,
		status_clr        => s_status_clr,
		
		my_mac_o  => CFG_MY_MAC,
		my_ip_o   => CFG_MY_IP,
		my_port_o => CFG_MY_PORT,
		
		local_slave_o     => CFG_2_EXT_slave,
		local_slave_i     => EXT_2_CFG_slave,
				
		eb_slave_o        => CFG_2_eb_slave,
		eb_slave_i        => eb_2_CFG_slave
    );

end behavioral; 
