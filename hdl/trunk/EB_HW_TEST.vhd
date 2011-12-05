--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wb32_package.all;
use work.wb16_package.all;

use work.vhdl_2008_workaround_pkg.all;


entity EB_HW_TEST is
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;
 
	alive_led_o		: out std_logic;
	bright_comp_o  : out std_logic;
	leds_o			: out std_logic_vector(7 downto 0 );	 
	hex_switch_i		: in std_logic_vector(3 downto 0) := "0000"	 
);	
end EB_HW_TEST;

architecture behavioral of EB_HW_TEST is



component wb_led_ctrl is 
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wb32_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wb32_slave_in;    --! 

		leds_o			: out	std_logic_vector(7 downto 0)
		
);
end component;


component EB_CORE is
generic(g_master_slave : natural := 1);
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
	hex_switch_i			: in std_logic_vector(3 downto 0);
	-- master IC IF ----------------------------------------------
	WB_master_i			: in	wb32_master_in;
	WB_master_o			: out	wb32_master_out
	--------------------------------------------------------------
	
);

end component;


component debouncer is
port(
	clk_i    		: in    std_logic;                                        --clock
 
	in_i			: in std_logic;
	out_o			: out std_logic
);	
end component debouncer;

constant WBM_Zero_o		: wb16_master_out := 	(CYC => '0',
												STB => '0',
												ADR => (others => '0'),
												SEL => (others => '0'),
												WE  => '0',
												DAT => (others => '0'));
												
constant WBS_Zero_o		: wb16_slave_out := 	(ACK   => '0',
												ERR   => '0',
												RTY   => '0',
												STALL => '0',
												DAT   => (others => '0'));

signal s_ebm_tx_i		: wb16_master_in;
signal s_ebm_tx_o		: wb16_master_out;
signal s_ebm_rx_i		: wb16_slave_in;
signal s_ebm_rx_o		: wb16_slave_out;

signal s_ebs_tx_i		: wb16_master_in;
signal s_ebs_tx_o		: wb16_master_out;
signal s_ebs_rx_i		: wb16_slave_in;
signal s_ebs_rx_o		: wb16_slave_out;

	
	--WB IC signals
signal s_WB_master_i			: wb32_master_in;
signal s_WB_master_o			: wb32_master_out;

signal s_wb_slave_o				: wb32_slave_out;
signal s_wb_slave_i				: wb32_slave_in;
signal s_leds					: std_logic_vector(7 downto 0);

signal RST  : std_logic;
signal bytecount : natural := 0;

signal max_buffersize : natural := 0;

signal divider : std_logic := '0';

constant WBS32_Zero_o		: wb32_slave_out := 	(ACK   => '0',
												ERR   => '0',
												RTY   => '0',
												STALL => '0',
												DAT   => (others => '0'));

signal s_alive_cnt : natural;
signal s_alive_led : std_logic;									
												
signal s_nRst_i : std_logic;
signal s_gen_nRst : std_logic; 
signal s_nRst_cnt : unsigned(31 downto 0);

											
												
begin




master: EB_CORE 	generic map(1)
port map ( clk_i             => clk_i,
	  nRst_i            => s_nRst_i,
	  slave_RX_CYC_i    => s_ebm_rx_i.CYC,
	  slave_RX_STB_i    => s_ebm_rx_i.STB,
	  slave_RX_DAT_i    => s_ebm_rx_i.DAT,
	  slave_RX_WE_i    => s_ebm_rx_i.WE,
	  slave_RX_STALL_o  => s_ebm_rx_o.STALL,
	  slave_RX_ERR_o    => s_ebm_rx_o.ERR,
	  slave_RX_ACK_o    => s_ebm_rx_o.ACK,
	  master_TX_CYC_o   => s_ebm_tx_o.CYC,
	  master_TX_STB_o   => s_ebm_tx_o.STB,
	  master_TX_DAT_o   => s_ebm_tx_o.DAT,
	  master_TX_WE_o   =>  s_ebm_tx_o.WE,
	  master_TX_STALL_i => s_ebm_tx_i.STALL,
	  master_TX_ERR_i   => s_ebm_tx_i.ERR,
	  master_TX_ACK_i   => s_ebm_tx_i.ACK,
	  debug_TX_TOL_o	=> open,
	  hex_switch_i		=> hex_switch_i,
	  WB_master_i       => WBS32_Zero_o,
	  WB_master_o       => open );

slave: EB_CORE 	generic map(0)
port map ( clk_i             => clk_i,
	  nRst_i            => s_nRst_i,
	  slave_RX_CYC_i    => s_ebs_rx_i.CYC,
	  slave_RX_STB_i    => s_ebs_rx_i.STB,
	  slave_RX_DAT_i    => s_ebs_rx_i.DAT,
	  slave_RX_WE_i    	=> s_ebs_rx_i.WE,
	  slave_RX_STALL_o  => s_ebs_rx_o.STALL,
	  slave_RX_ERR_o    => s_ebs_rx_o.ERR,
	  slave_RX_ACK_o    => s_ebs_rx_o.ACK,
	  master_TX_CYC_o   => s_ebs_tx_o.CYC,
	  master_TX_STB_o   => s_ebs_tx_o.STB,
	  master_TX_DAT_o   => s_ebs_tx_o.DAT,
	  master_TX_WE_o   	=> s_ebs_tx_o.WE,
	  master_TX_STALL_i => s_ebs_tx_i.STALL,
	  master_TX_ERR_i   => s_ebs_tx_i.ERR,
	  master_TX_ACK_i   => s_ebs_tx_i.ACK,
	  debug_TX_TOL_o	=> open,
	  hex_switch_i		=> (others => '0'),
	  WB_master_i       => s_WB_master_i,
	  WB_master_o       => s_WB_master_o );

 
s_ebm_tx_i	<=	s_ebs_rx_o;
s_ebm_rx_i	<=	s_ebs_tx_o;
s_ebs_tx_i	<=	s_ebm_rx_o;
s_ebs_rx_i	<=	s_ebm_tx_o;
 

 
WB_DEV : wb_led_ctrl
port map(
		clk_i	=> clk_i,
		nRst_i	=> s_nRst_i,
		
		wb_slave_o     	=> s_WB_master_i,	
		wb_slave_i     	=> s_WB_master_o ,
		leds_o			=> s_leds
    );

leds_o	<= s_leds;

deb_nrst : debouncer
port map(
		clk_i	=> clk_i,
		
		in_i	=> nRst_i,
		out_o	=> s_gen_nRst
    );

gen_nrst : process (clk_i)



  begin
      if (clk_i'event and clk_i = '1') then
				s_nRst_i <= s_nRst_cnt(s_nRst_cnt'left);
				
				if(s_gen_nRst = '0') then
					s_nRst_cnt <= to_unsigned(125,32); -- 1ms	
				else
					if(s_nRst_cnt(s_nRst_cnt'left) = '0') then
						s_nRst_cnt <= s_nRst_cnt -1;
					end if;
				end if;
		end if;

end process;


	 
	 
lifesign	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
			if( s_nRst_i  = '0' ) then  --reset counter
			  s_alive_cnt <= 0;
			  s_alive_led <= '0';
			else
				if(s_alive_cnt > 125000000) then
					s_alive_cnt <= 0;
					s_alive_led <= NOT s_alive_led;
				else
					s_alive_cnt <= s_alive_cnt + 1;
				end if;
			end if;
    end if;
end process;

alive_led_o <= s_alive_led;
	
bright_comp_o <= '0';

	
	

end architecture behavioral;   


