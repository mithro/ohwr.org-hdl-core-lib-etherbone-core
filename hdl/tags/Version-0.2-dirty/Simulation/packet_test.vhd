--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wb32_package.all;
use work.wb16_package.all;


entity packet_test is 
end packet_test;

architecture behavioral of packet_test is

component binary_source is
generic(filename : string := "123.dat";  wordsize : natural := 16; endian : natural := 0);
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

signal stop_the_clock : boolean := false;
signal firstrun : boolean := true;
constant clock_period: time := 8 ns;

	--Eth MAC WB Streaming signals

signal s_master_TX_stream_o		: wb16_master_out;



signal rdy : std_logic;
signal request : std_logic;


type FSM is (INIT, INIT_DONE, PACKET_HDR, CYCLE_HDR, RD_BASE_ADR, RD, WR_BASE_ADR, WR, CYC_DONE, PACKET_DONE, DONE);
signal state : FSM := INIT;	

signal end_sim : std_logic := '1';
signal capture : std_logic := '1';

signal pcap_in_wren : std_logic := '0';
signal pcap_out_wren : std_logic := '0';




begin


	
stream_src : binary_source
generic map(filename => "source.dat", wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,

	rdy_o	=> rdy,
	
	run_i		=> s_master_TX_stream_o.CYC,
	request_i	=> request,
	valid_o		=> s_master_TX_stream_o.STB,
	data_o		=> s_master_TX_stream_o.DAT
);
	
	
pcapin : packet_capture
generic map(filename => "eb_input2.pcap", wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,

	TOL_i	=> x"DEAD",
	
	sample_i		=> s_master_TX_stream_o.CYC,
	valid_i			=> s_master_TX_stream_o.STB,
	data_i			=> s_master_TX_stream_o.DAT
);





    clkGen : process
    variable dead : integer := 3;
	
	begin 
      while 1=1 loop
         s_clk_i <= '0', '1' after clock_period / 2;
         wait for clock_period;
		 if(stop_the_clock) then
			end_sim <= '0';
			dead := dead -1;
		 end if;
		 if dead = 0 then
			report "simulation end" severity failure;
		 end if;
      end loop;
	  
	  end_sim <= '0';
	  --wait for clock_period * 5;
	  report "simulation end" severity failure;
    end process clkGen;
    
	
    rx_packet : process
    
	
	    variable i : integer := 0;
	    
		variable packets : natural := 0;
		variable cycles : natural := 0;
		variable rds : natural := 0;
		variable wrs : natural := 0;
    
    begin
        wait until rising_edge(s_clk_i);
		s_nRst_i <= '0';
		wait for clock_period;
		s_nRst_i <= '1';
		wait for clock_period;
		
		s_master_TX_stream_o.CYC <= '1';
		while(rdy = '0') loop
			wait for clock_period;
		end loop;	
		request <= '1';
		while(rdy = '1') loop
			wait for clock_period;
		end loop;
		s_master_TX_stream_o.CYC <= '0';
		request <= '0';
		stop_the_clock <= true;
	end process rx_packet;
		




end architecture behavioral;   


