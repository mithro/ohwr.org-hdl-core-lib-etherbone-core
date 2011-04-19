--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.EB_components_pkg.all;
use work.wishbone_package.all;


entity EB_CORE is 
port
(
	clk_i           	: in    std_logic;   --! clock input
	nRst_i				: in 	std_logic;
	
	slave_RX_stream_std_i	: in	std_logic_vector(70 downto 0);	--wishbone_slave_in;
	slave_RX_stream_std_o	: out	std_logic_vector(35 downto 0);	--wishbone_slave_out;

	master_TX_stream_std_i	: in	std_logic_vector(35 downto 0); --wishbone_master_in;
	master_TX_stream_std_o	: out	std_logic_vector(70 downto 0); --wishbone_master_out;
	
	master_IC_std_i			: in	std_logic_vector(35 downto 0); ---wishbone_master_in;
	master_IC_std_o			: out	std_logic_vector(70 downto 0) --wishbone_master_out
	
);
end EB_CORE;

architecture behavioral of EB_CORE is

-- TX CTRL  <-> EBCORE signals

signal EB_2_TXCTRL_wb_slave			: wishbone_slave_in;
signal TXCTRL_2_EB_wb_slave 		: wishbone_slave_out;


signal EB_2_RXCTRL_wb_master		: wishbone_master_in;
signal RXCTRL_2_EB_wb_master 		: wishbone_master_out;

-- convert to/from std_logic_vector
-----------------------------------------------------
signal slave_RX_stream_i	: wishbone_slave_in;
signal slave_RX_stream_o	: wishbone_slave_out;

signal master_TX_stream_i	: wishbone_master_in;
signal master_TX_stream_o	: wishbone_master_out;
	
signal master_IC_i			: wishbone_master_in;
signal master_IC_o			: wishbone_master_out;
-----------------------------------------------------

-- RX CTRL <-> TXCTRL signals
signal RXCTRL_2_TXCTRL_reply_MAC 	: std_logic_vector(47 downto 0);
signal RXCTRL_2_TXCTRL_reply_IP 	: std_logic_vector(31 downto 0);
signal RXCTRL_2_TXCTRL_reply_PORT 	: std_logic_vector(15 downto 0);
signal RXCTRL_2_TXCTRL_TOL 			: std_logic_vector(15 downto 0);
signal RXCTRL_2_TXCTRL_valid 		: std_logic;

--EB <-> TXCTRL
signal EB_2_TXCTRL_wb_master		: wishbone_master_out;
signal TXCTRL_2_EB_wb_master 		: wishbone_master_in;

--EB <-> RXCTRL
signal EB_2_RXCTRL_wb_slave			: wishbone_slave_out;
signal RXCTRL_2_EB_wb_slave 		: wishbone_slave_in;


 begin
 
 -- convert to/from std_logic_vector
-----------------------------------------------------
slave_RX_stream_i		<=	TO_wishbone_slave_in(slave_RX_stream_std_i);	-- wishbone_slave_in;
slave_RX_stream_std_o	<=	TO_STD_LOGIC_VECTOR(slave_RX_stream_o); 		-- wishbone_slave_out;

master_TX_stream_i		<=	TO_wishbone_master_in(master_TX_stream_std_i);	-- wishbone_master_in;
master_TX_stream_std_o	<=	TO_STD_LOGIC_VECTOR(master_TX_stream_o);	-- wishbone_master_out;
	
master_IC_i				<=	TO_wishbone_master_in(master_IC_std_i);			-- wishbone_master_in;
master_IC_std_o			<=	TO_STD_LOGIC_VECTOR(master_IC_o);				-- wishbone_master_out;

-----------------------------------------------------
 
 
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
EB_2_TXCTRL_wb_slave 		<= wishbone_slave_in(EB_2_TXCTRL_wb_master);
TXCTRL_2_EB_wb_master 		<= wishbone_master_in(TXCTRL_2_EB_wb_slave);

EB_2_RXCTRL_wb_master		<= wishbone_master_in(EB_2_RXCTRL_wb_slave);
RXCTRL_2_EB_wb_slave 		<= wishbone_slave_in(RXCTRL_2_EB_wb_master);


 
 
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