--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wishbone_package.all;

entity TB_GENERATORS is 
end TB_GENERATORS;

architecture behavioral of TB_GENERATORS is



component AV_STSRC_WB_SLV is 
generic(g_data_width : natural := 32);
port
(
   csi_clk              : in     std_logic;   --! clock input
   csi_n_rst            : in     std_logic;   --! reset input, active low   

   --Wishbone Master IOs
   --wb_slave_slv_o          : out    wishbone_slave_out;	--! Wishbone master output lines
   --wb_slave_i          : in     wishbone_slave_in;    --! 
   
	wb_slave_slv_o          : out    std_logic_vector(35 downto 0);	--! Wishbone master output lines
    wb_slave_slv_i          : in     std_logic_vector(70 downto 0);
   --Avalon Streaming SRC IOs

	AVS_M_VALID          	: out    std_logic;
	AVS_M_STARTOFPACKET     : out    std_logic;
	AVS_M_ENDOFPACKET        : out    std_logic;
	AVS_M_DATA      		: out    std_logic_vector(31 downto 0);
	

	AVS_M_ERROR    			: out    std_logic;
	AVS_M_EMPTY     		: out    std_logic_vector(1 downto 0);
	
	AVS_SL_READY         	: in     std_logic
      
);
end component;

   --Avalon Streaming SINK IOs

signal s_AVS_M_VALID          	: std_logic;
signal s_AVS_M_STARTOFPACKET     : std_logic;
signal s_AVS_M_ENDOFPACKET        : std_logic;
signal s_AVS_M_DATA      		: std_logic_vector(31 downto 0);
	
signal s_AVS_SL_READY         	: std_logic := '1';
	
	--not used
	--AVS_M_CHANNEL    		: in    std_logic_vector(1 downto 0);
signal s_AVS_M_ERROR    			: std_logic := '0';
signal s_AVS_M_ERROR6    		: std_logic_vector(5 downto 0) := (others => '0');
signal s_AVS_M_EMPTY     		: std_logic_vector(1 downto 0) := (others => '0');


component EB_TX_CTRL is 
port(
		clk_i		: in std_logic;
		nRst_i		: in std_logic;
		
		--Eth MAC WB Streaming signals
		wb_slave_i	: in	wishbone_slave_in;
		wb_slave_o	: out	wishbone_slave_out;

		TX_master_slv_o          : out   std_logic_vector(70 downto 0);	--! Wishbone master output lines
		TX_master_slv_i          : in     std_logic_vector(35 downto 0)    --! 
		--TX_master_o     : out   wishbone_master_out;	--! Wishbone master output lines
		--TX_master_i     : in    wishbone_master_in    --!
		

		
		-- REP_MAC_i			: std_logic_vector(47 downto 0);
		-- REP_IP_i			: std_logic_vector(31 downto 0);
		-- REP_PORT_i			: std_logic_vector(15 downto 0);
		--EB Core Streaming signals
		-- udp_byte_len_i		: out unsigned(15 downto 0);
		
		-- valid_o				: std_logic
		
);
end component ;

   --Wishbone Master IOs
signal s_TX_master_slv_o          : std_logic_vector(70 downto 0);	--! Wishbone master output lines
signal s_TX_master_slv_i            : std_logic_vector(35 downto 0);
signal s_wb_slave_o   :       wishbone_slave_out;	--! Wishbone master output lines
signal s_wb_slave_i    :      wishbone_slave_in;


component wb_test_gen is 
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_master_o     : out   wishbone_master_out;	--! Wishbone master output lines
		wb_master_i     : in    wishbone_master_in    --!
);

end component;

signal s_wb_master_o  :        wishbone_master_out;	--! Wishbone master output lines
signal s_wb_master_i   :       wishbone_master_in;



signal s_clk_i : std_logic := '0';
signal s_nRST_i : std_logic := '0';
signal stop_the_clock : boolean := false;
signal firstrun : std_logic := '1';
constant clock_period: time := 8 ns;


--- bridges


 





begin

s_wb_slave_i   <=       wishbone_slave_in(s_wb_master_o);	--! Wishbone master output lines
s_wb_master_i  <=        wishbone_master_in(s_wb_slave_o);	--! Wishbone master output lines
	


TBwards : AV_STSRC_WB_SLV 
generic map(g_data_width => 32)
port map
(
    csi_clk             => s_clk_i,
   csi_n_rst            => s_nRst_i,   

   wb_slave_slv_o          	=> s_TX_master_slv_i,
   wb_slave_slv_i          	=> s_TX_master_slv_o,
   
   --Avalon Streaming SINK IOs

	AVS_M_VALID         => s_AVS_M_VALID,
	AVS_M_STARTOFPACKET => s_AVS_M_STARTOFPACKET,
	AVS_M_ENDOFPACKET   => s_AVS_M_ENDOFPACKET,
	AVS_M_DATA      	=> s_AVS_M_DATA,
	
	AVS_SL_READY        => s_AVS_SL_READY,
	
	--not used
	--AVS_M_CHANNEL    		: in    std_logic_vector(1 downto 0);
	AVS_M_ERROR    		=> s_AVS_M_ERROR,
	AVS_M_EMPTY     	=>  s_AVS_M_EMPTY
      
);

HDRGEN : EB_TX_CTRL
port map
(
		clk_i             => s_clk_i,
  nRST_i            => s_nRst_i, 
		
		--Eth MAC WB Streaming signals
		wb_slave_i	=> s_wb_slave_i,
		wb_slave_o	=> s_wb_slave_o,

		TX_master_slv_o  =>        s_TX_master_slv_o,	--! Wishbone master output lines
		TX_master_slv_i  =>        s_TX_master_slv_i    --! 
		--TX_master_o     : out   wishbone_master_out;	--! Wishbone master output lines
		--TX_master_i     : in    wishbone_master_in    --!
		

		
		-- REP_MAC_i			: std_logic_vector(47 downto 0);
		-- REP_IP_i			: std_logic_vector(31 downto 0);
		-- REP_PORT_i			: std_logic_vector(15 downto 0);
		--EB Core Streaming signals
		-- udp_byte_len_i		: out unsigned(15 downto 0);
		
		-- valid_o				: std_logic
		
);



TGEN : wb_test_gen
port map(
		clk_i	=> s_clk_i,
		nRst_i	=> s_nRst_i,
		
		wb_master_o     	=> s_wb_master_o,	
		wb_master_i     	=> s_wb_master_i  

		
    );






    clkGen : process
    begin 
      while not stop_the_clock loop
         s_clk_i <= '0', '1' after clock_period / 2;
         wait for clock_period;
      end loop;
	  report "simulation end" severity failure;
    end process clkGen;
    

	


end architecture behavioral;   


