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

	-- master IC IF ----------------------------------------------
	master_IC_i			: in	wb32_master_in;
	master_IC_o			: out	wb32_master_out
	--------------------------------------------------------------
	
);
end EB_CORE;

architecture behavioral of EB_CORE is

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

signal	slave_RX_stream_i	:		wb16_slave_in;
signal	slave_RX_stream_o	:		wb16_slave_out;

signal	master_TX_stream_i	:		wb16_master_in;
signal	master_TX_stream_o	:		wb16_master_out;

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
		slave_RX_stream_i	: in	wb32_slave_in;
		slave_RX_stream_o	: out	wb32_slave_out;

		master_TX_stream_i	: in	wb32_master_in;
		master_TX_stream_o	: out	wb32_master_out;

		byte_count_rx_i			: in std_logic_vector(15 downto 0);
		
		--WB IC signals
		master_IC_i	: in	wb32_master_in;
		master_IC_o	: out	wb32_master_out

);
end component;

 begin
 
 TXCTRL : EB_TX_CTRL
port map
(
		clk_i             => clk_i,
		nRST_i            => nRst_i, 
		
		--Eth MAC WB Streaming signals
		wb_slave_i	=> EB_2_TXCTRL_wb_slave,
		wb_slave_o	=> TXCTRL_2_EB_wb_slave,

		TX_master_o     =>	master_TX_stream_o,
		TX_master_i     =>  master_TX_stream_i,  --!
		
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
     							 
							 RX_slave_o => slave_RX_stream_o,
                             RX_slave_i => slave_RX_stream_i,
							 
                             reply_MAC_o    => RXCTRL_2_TXCTRL_reply_MAC,
                             reply_IP_o     => RXCTRL_2_TXCTRL_reply_IP,
                             reply_PORT_o   => RXCTRL_2_TXCTRL_reply_PORT,
                             TOL_o          => RXCTRL_2_TXCTRL_TOL,
                             valid_o        => RXCTRL_2_TXCTRL_valid);
 

 -- EB type conversions for WB daisychain
EB_2_TXCTRL_wb_slave 		<= wb32_slave_in(EB_2_TXCTRL_wb_master);
TXCTRL_2_EB_wb_master 		<= wb32_master_in(TXCTRL_2_EB_wb_slave);

EB_2_RXCTRL_wb_master		<= wb32_master_in(EB_2_RXCTRL_wb_slave);
RXCTRL_2_EB_wb_slave 		<= wb32_slave_in(RXCTRL_2_EB_wb_master);

-- assign records to individual bus signals.
-- slave RX
slave_RX_stream_i.CYC 		<= slave_RX_CYC_i;
slave_RX_stream_i.STB 		<= slave_RX_STB_i;
slave_RX_stream_i.DAT 		<= slave_RX_DAT_i;
slave_RX_stream_i.WE 		<= slave_RX_WE_i;
slave_RX_STALL_o 			<= slave_RX_stream_o.STALL;						
slave_RX_ERR_o 				<= slave_RX_stream_o.ERR;
slave_RX_ACK_o 				<= slave_RX_stream_o.ACK;

-- master TX
master_TX_CYC_o				<= master_TX_stream_o.CYC;
master_TX_STB_o				<= master_TX_stream_o.STB;
master_TX_DAT_o				<= master_TX_stream_o.DAT;
master_TX_WE_o				<= master_TX_stream_o.WE;
master_TX_stream_i.STALL 	<= master_TX_STALL_i;						
master_TX_stream_i.ERR 		<= master_TX_ERR_i;
master_TX_stream_i.ACK 		<= master_TX_ACK_i;


 
 EB : eb_2_wb_converter
port map(
       --general
	clk_i	=> clk_i,
	nRst_i	=> nRst_i,

	--Eth MAC WB Streaming signals
	slave_RX_stream_i	=> RXCTRL_2_EB_wb_slave,
	slave_RX_stream_o	=> EB_2_RXCTRL_wb_slave,

	master_TX_stream_i	=> TXCTRL_2_EB_wb_master,
	master_TX_stream_o	=> EB_2_TXCTRL_wb_master,

    byte_count_rx_i		=> RXCTRL_2_TXCTRL_TOL,

	
	--WB IC signals
	master_IC_i			=> master_IC_i,
	master_IC_o			=> master_IC_o
);  
 
 

end behavioral; 