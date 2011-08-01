--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wb32_package.all;
use work.wb16_package.all;


entity TB_EB4 is 
end TB_EB4;

architecture behavioral of TB_EB4 is

component binary_source is
generic(filename : string := "123.dat";  wordsize : natural := 32; endian : natural := 0);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	
	rdy_o			: out  	std_logic;
	run_i		: in   	std_logic;
	request_i		: in 	std_logic;
	valid_o			: out	std_logic;	
	data_o			: out	std_logic_vector(wordsize-1 downto 0)
);	
end component;

component wb_timer 
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wb32_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wb32_slave_in;    --! 

		signal_out	   : out std_logic_vector(31 downto 0);			
		
		compmatchA_o		: out	std_logic;
		n_compmatchA_o		: out	std_logic;
		
		compmatchB_o		: out	std_logic;
		n_compmatchB_o		: out	std_logic
    );

end component;

component packet_capture is
generic(filename : string := "123.pcap";  wordsize : natural := 32);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	TOL_i		: in 	std_logic_vector(15 downto 0);
	
	sample_i		: in   	std_logic;
	valid_i			: in   	std_logic;
	data_i			: in	std_logic_vector(wordsize-1 downto 0)
);	
end component;

component EB_CORE is 
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


----------------------------------------------------------------------------------
constant c_PACKETS  : natural := 1;
constant c_CYCLES   : natural := 2;
constant c_RDS      : natural := 4;
constant c_WRS      : natural := 4;

constant c_READ_START 	: unsigned(31 downto 0) := x"0000000C";
constant c_REPLY_START	: unsigned(31 downto 0) := x"ADD3E550";

constant c_WRITE_START 	: unsigned(31 downto 0) := x"00000010";
constant c_WRITE_VAL	: unsigned(31 downto 0) := x"0000000F";
----------------------------------------------------------------------------------







signal s_clk_i : std_logic := '0';
signal s_nRST_i : std_logic := '0';
signal nRST_i : std_logic := '0';

signal stop_the_clock : std_logic := '0';
signal firstrun : boolean := true;
constant clock_period: time := 8 ns;

	--Eth MAC WB Streaming signals
signal s_slave_RX_stream_i		: wb32_slave_in;
signal s_slave_RX_stream_o		: wb32_slave_out;
signal s_master_TX_stream_i		: wb16_master_in;
signal s_master_TX_stream_o		: wb16_master_out;

signal s_txctrl_i		: wb16_master_in;
signal s_txctrl_o		: wb16_master_out;
signal s_ebcore_i		: wb16_slave_in;
signal s_ebcore_o		: wb16_slave_out;

signal s_byte_count_i			: unsigned(15 downto 0);
signal s_byte_count_o			: unsigned(15 downto 0);
	
	--WB IC signals
signal s_master_IC_i			: wb32_master_in;
signal s_master_IC_o			: wb32_master_out;

signal s_wb_slave_o				: wb32_slave_out;
signal s_wb_slave_i				: wb32_slave_in;

 --x4 because it's bytes
signal TOL		: std_logic_vector(15 downto 0);

signal RX_EB_HDR : EB_HDR;
signal RX_EB_CYC : EB_CYC;

signal s_oc_a : std_logic;
signal s_oc_an : std_logic;
signal s_oc_b : std_logic;
signal s_oc_bn : std_logic;

type FSM is (INIT, INIT_DONE, PACKET_HDR, CYCLE_HDR, RD_BASE_ADR, RD, WR_BASE_ADR, WR, CYC_DONE, PACKET_DONE, DONE);
signal state : FSM := INIT;	

signal stall : std_logic := '0';
signal end_sim : std_logic := '1';
signal capture : std_logic := '1';

signal pcap_in_wren : std_logic := '0';
signal pcap_out_wren : std_logic := '0';

signal s_signal_out : std_logic_vector(31 downto 0);

signal rdy : std_logic;
signal request : std_logic;
signal stalled: std_logic;
signal strobe: std_logic;
signal start : std_logic;

begin

stream_src : binary_source
generic map(filename => "source.dat", wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,

	rdy_o	=> rdy,
	
	run_i		=> start,
	request_i	=> request,
	valid_o		=> strobe,
	data_o		=> s_ebcore_i.DAT
);

start <= s_ebcore_i.CYC AND NOT stop_the_clock ;
request <= rdy AND NOT (s_ebcore_o.STALL OR stalled); 
s_ebcore_i.STB <= strobe OR s_ebcore_o.STALL OR stalled;




TOL <= std_logic_vector(to_unsigned(88, 16));

  core: EB_CORE port map ( clk_i             => s_clk_i,
                          nRst_i            => s_nRst_i,
                          slave_RX_CYC_i    => s_ebcore_i.CYC,
                          slave_RX_STB_i    => s_ebcore_i.STB,
                          slave_RX_DAT_i    => s_ebcore_i.DAT,
                          slave_RX_WE_i    => s_ebcore_i.WE,
						  slave_RX_STALL_o  => s_ebcore_o.STALL,
                          slave_RX_ERR_o    => s_ebcore_o.ERR,
                          slave_RX_ACK_o    => s_ebcore_o.ACK,
                          master_TX_CYC_o   => s_master_TX_stream_o.CYC,
                          master_TX_STB_o   => s_master_TX_stream_o.STB,
                          master_TX_DAT_o   => s_master_TX_stream_o.DAT,
						  master_TX_WE_o   => s_master_TX_stream_o.WE,
                          master_TX_STALL_i => s_master_TX_stream_i.STALL,
                          master_TX_ERR_i   => s_master_TX_stream_i.ERR,
                          master_TX_ACK_i   => s_master_TX_stream_i.ACK,
                          master_IC_i       => s_master_IC_i,
                          master_IC_o       => s_master_IC_o );

 

s_txctrl_i	<= wb16_slave_out(s_ebcore_o);



 



WB_DEV : wb_timer
generic map(g_cnt_width => 32) 
port map(
		clk_i	=> s_clk_i,
		nRst_i	=> s_nRst_i,
		
		wb_slave_o     	=> s_wb_slave_o,	
		wb_slave_i     	=> s_wb_slave_i,  
		signal_out	   => s_signal_out,	
		compmatchA_o	=> s_oc_a,
		n_compmatchA_o	=> s_oc_an,
		compmatchB_o	=> s_oc_b,
		n_compmatchB_o  => s_oc_bn
    );


	s_master_IC_i <= wb32_master_in(s_wb_slave_o);
	s_wb_slave_i <= wb32_slave_in(s_master_IC_o);

	
pcapin : packet_capture
generic map(filename => "eb_input2.pcap", wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,

	TOL_i	=> TOL,
	
	sample_i		=> capture,
	valid_i			=> pcap_in_wren,
	data_i			=> s_ebcore_i.DAT
);

	pcap_in_wren <= (s_ebcore_i.STB AND (NOT s_ebcore_o.STALL));

pcapout : packet_capture
generic map(filename => "eb_output.pcap",  wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,

	TOL_i	=> TOL,
	
	sample_i		=> capture,
	valid_i			=> pcap_out_wren,
	data_i			=> s_master_TX_stream_o.DAT
);		

pcap_out_wren <= (s_master_TX_stream_o.STB AND (NOT s_master_TX_stream_i.STALL));

clocked : process(s_clk_i)
begin
if (s_clk_i'event and s_clk_i = '1') then
		if(nRSt_i = '0') then
		else
			stalled <= s_ebcore_o.STALL; 
		end if;	
	end if;
end process;




    clkGen : process
    variable dead : integer := 50;
	
	begin 
      while 1=1 loop
         s_clk_i <= '0', '1' after clock_period / 2;
         wait for clock_period;
		 if(stop_the_clock = '1') then
			
			dead := dead -1;
		 end if;
		 if dead = 0 then
			end_sim <= '0';
	
			report "simulation end" severity failure;
		 end if;
      end loop;
	  
	  end_sim <= '0';
	  wait for clock_period * 5;
	  report "simulation end" severity failure;
    end process clkGen;
    
	s_nRST_i <= nRST_i AND end_sim;
	
    rx_packet : process
    
	
	    variable i : integer := 0;
	    
		variable packets : natural := 0;
		variable cycles : natural := 0;
		variable rds : natural := 0;
		variable wrs : natural := 0;
    
    begin
        wait until rising_edge(s_clk_i);

		nRst_i <= '0';
		s_master_TX_stream_i.STALL <= '0';
		wait for clock_period;
		
		nRst_i <= '1';
		wait for clock_period;
		s_ebcore_i.WE 	<= '1';
		s_ebcore_i.CYC 	<= '1';
		capture <= '1';
		while(rdy = '0') loop
			wait for clock_period;
		end loop;	
		--request <= '1';
		while(rdy = '1') loop
			wait for clock_period;
		end loop;
		
		--request <= '0';
		stop_the_clock <= '1';
		wait for 48*clock_period; 
		s_ebcore_i.CYC 	<= '0';
		capture <= '0';

		wait;
	end process rx_packet;
	


end architecture behavioral;   


