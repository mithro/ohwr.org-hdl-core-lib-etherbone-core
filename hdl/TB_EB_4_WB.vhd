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


entity TB_EB4 is 
end TB_EB4;

architecture behavioral of TB_EB4 is

--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------
constant c_PACKETS  : natural := 1;
constant c_CYCLES   : natural := 8;

type rws is array (1 downto 0) of natural;
type rws_cycle is array (0 to c_CYCLES-1) of rws;

subtype flagvec is std_logic_vector(5 downto 0);
type flags_cycle is array(0 to c_CYCLES-1) of flagvec;

subtype word is std_logic_vector(15 downto 0); 
type eth_packet  is array (750 downto 0) of word;

constant c_READ_START 	: unsigned(31 downto 0) := x"0000000C";
constant c_REPLY_START	: unsigned(31 downto 0) := x"ADD3E550";

constant c_WRITE_START 	: unsigned(31 downto 0) := x"00000010";
constant c_WRITE_VAL	: unsigned(31 downto 0) := x"0000000F";

constant cyc1rw : rws_cycle := ((1, 0), (0, 1), (1, 1), (1, 10), (10, 1), (10, 0), (0, 10), (10, 10));--, (0, 1), (1, 0), (0, 1), (13, 40));
--constant flags1 : flags_cycle := ("110100", "110110", "100100");--, "001100", "100101");
signal pack1 : eth_packet := (others => (others => '0'));
--------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------












component packet_source is
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

component wb_test 
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wb32_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wb32_slave_in
    );

end component;

component packet_capture is
generic(filename : string := "123.pcap";  wordsize : natural := 32);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	TOL_i		: in 	std_logic_vector(15 downto 0);
	rdy_o		: out std_logic;
	start_i		: in   	std_logic;
	packet_start_i		: in   	std_logic;
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
	debug_TX_TOL_o			: out std_logic_vector(15 downto 0);
	
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



function calc_packet_length(cycles : rws_cycle)
return natural is

	variable tmp : natural := 0;
	variable len : natural := cycles'length;
	variable rd : natural := 0;
	variable wr : natural := 0;
	
	variable output  : natural := (c_HDR_LEN + 4); -- ETH/UDP/IP HDR + EB 4 byte. min
	begin
		for i in 0 to len-1 loop
			rd := cycles(i)(0);
			wr := cycles(i)(1);
			tmp := tmp + rd + wr + sign(rd) + sign(wr) + 1; -- cyc hdr, rd_back_adr, wr_start_adr
		end loop;
		output := output + (tmp * 4); -- 32b words
		
	return output;
end function calc_packet_length; 


function create_EB_CYC(packet : eth_packet; pPtr : natural; writes : natural; reads : natural; flags : std_logic_vector; wr_start : std_logic_vector; rd_start : std_logic_vector; rd_back : std_logic_vector)
return eth_packet is

	variable tmp : EB_CYC;
	variable tmp32b : std_logic_vector(31 downto 0);
	variable inc : natural;
	variable tmp_packet : eth_packet := packet;
	variable tmp_pPtr : natural := pPtr;
	
	begin
		tmp.RESERVED1 	:= '0';
		tmp.RESERVED2 	:= '0';
		tmp.RESERVED3 	:= x"00";
		
		tmp.BCA_CFG 	:=	flags(5);
		tmp.RCA_CFG 	:= 	flags(4);
		tmp.RD_FIFO 	:=	flags(3);
		tmp.DROP_CYC 	:=  flags(2);
		tmp.WCA_CFG		:= 	flags(1);	
		tmp.WR_FIFO 	:=	flags(0);
		tmp.WR_CNT		:=	to_unsigned(writes,8);
		tmp.RD_CNT		:=	to_unsigned(reads,8);
		
		-- write EB cycle header
		tmp32b := to_std_logic_vector(tmp);
		tmp_packet(tmp_pPtr) := tmp32b(31 downto 16);
		tmp_pPtr := tmp_pPtr-1;
		tmp_packet(tmp_pPtr) := tmp32b(15 downto 0);
		tmp_pPtr := tmp_pPtr-1;
		
		if(writes > 0) then
			-- write Write start addr
			tmp_packet(tmp_pPtr) := wr_start(31 downto 16);
			tmp_pPtr := tmp_pPtr-1;
			tmp_packet(tmp_pPtr) := wr_start(15 downto 0);
			tmp_pPtr := tmp_pPtr-1;
			
			--write Write Values
			for i in 0 to writes-1 loop
				tmp_packet(tmp_pPtr) := x"DA7A";
				tmp_pPtr := tmp_pPtr-1;
				tmp_packet(tmp_pPtr) := std_logic_vector(to_unsigned(i, 16));
				tmp_pPtr := tmp_pPtr-1;
			end loop;
		end if;
		
		if(reads > 0) then
			-- read back addr
			tmp_packet(tmp_pPtr) := rd_back(31 downto 16);
			tmp_pPtr := tmp_pPtr-1;
			tmp_packet(tmp_pPtr) := rd_back(15 downto 0);
			tmp_pPtr := tmp_pPtr-1;
			
			if(tmp.RD_FIFO = '0') then
				inc := 4;
			else
				inc := 0;
			end if;	
			for i in 0 to reads-1 loop
				tmp32b := std_logic_vector((unsigned(rd_start) +  to_unsigned(i*inc, 32)));
				
				tmp_packet(tmp_pPtr) := tmp32b(31 downto 16);
				tmp_pPtr := tmp_pPtr-1;
				tmp_packet(tmp_pPtr) := tmp32b(15 downto 0);
				tmp_pPtr := tmp_pPtr-1;
			end loop;
		end if;
	return tmp_packet;
end function create_EB_CYC; 


function calc_ip_chksum(input : IPV4_HDR)
return std_logic_vector is
    variable tmp : unsigned(c_IPV4_HLEN-1 downto 0) := (others => '0'); 
	variable output : std_logic_vector(15 downto 0) := (others => '0');
	variable tmp_sum : unsigned(31 downto 0) := (others => '0');
	variable tmp_slice : unsigned(15 downto 0) := (others => '0');
	begin
 		tmp := unsigned(to_std_logic_vector(input));
		for i in c_IPV4_HLEN/16-1 downto 0 loop 
			tmp_slice := tmp((i+1)*16-1 downto i*16);
			tmp_sum := tmp_sum + (x"0000" & tmp_slice); 
		end loop;
		tmp_sum := (x"0000" & tmp_sum(15 downto 0)) + (x"0000" + tmp_sum(31 downto 16));
		output := std_logic_vector(NOT(tmp_sum(15 downto 0) + tmp_sum(31 downto 16)));
	return output;
end function calc_ip_chksum; 


constant tol1 : natural := calc_packet_length(cyc1rw);

















signal s_clk_i : std_logic := '0';
signal s_nRST_i : std_logic := '0';
signal nRST_i : std_logic := '0';

signal stop_the_clock : std_logic := '0';
signal firstrun : boolean := true;
constant clock_period: time := 8 ns;

	--Eth MAC WB Streaming signals
signal s_byte_count_i			: unsigned(15 downto 0);
signal s_byte_count_o			: unsigned(15 downto 0);
	



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
signal strobed: std_logic;
signal start : std_logic;
signal packet_start : std_logic;
signal start_test : std_logic := '0';


signal gen_strobe: std_logic;
signal gen_start : std_logic;
signal gen_packet_start : std_logic;
signal gen_rdy : std_logic;

signal pack_tmp : std_logic_vector(15 downto 0);











	--Eth MAC WB Streaming signals
signal s_slave_RX_stream_i		: wb32_slave_in;
signal s_slave_RX_stream_o		: wb32_slave_out;
signal s_master_TX_stream_i		: wb16_master_in;
signal s_master_TX_stream_o		: wb16_master_out;

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

signal s_txctrl_i		: wb16_master_in;
signal s_txctrl_o		: wb16_master_out;
signal s_ebcore_i		: wb16_slave_in := WBM_Zero_o;
signal s_ebcore_o		: wb16_slave_out := WBS_Zero_o;



												
--signal s_byte_count_i			: unsigned(15 downto 0);
--signal s_byte_count_o			: unsigned(15 downto 0);
	
	--WB IC signals
signal s_master_IC_i			: wb32_master_in;
signal s_master_IC_o			: wb32_master_out;

signal s_wb_slave_o				: wb32_slave_out;
signal s_wb_slave_i				: wb32_slave_in;


signal rdy1 : std_logic;
signal rdy2 : std_logic;
--signal request : std_logic;
--signal stalled: std_logic;
--signal strobe: std_logic;
--signal start : std_logic;
signal RST  : std_logic;
signal bytecount : natural := 0;

signal max_buffersize : natural := 0;

signal divider : std_logic := '0';

begin

packet_gen : packet_capture
generic map(filename => "test_V4.pcap",  wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> nRst_i,

	TOL_i	=> word(to_unsigned(tol1,16)),
	rdy_o => gen_rdy,
	start_i		=> gen_start,
	packet_start_i => gen_packet_start,
	valid_i			=> gen_strobe,
	data_i			=> pack_tmp
);	







stream_src : packet_source
generic map(filename => "test_V4.pcap", wordsize => 16) 
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
-- AND divider


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
                          debug_TX_TOL_o	=> TOL,
						  master_IC_i       => s_master_IC_i,
                          master_IC_o       => s_master_IC_o );

 

s_txctrl_i	<= wb16_slave_out(s_ebcore_o);


RST <= nRst_i AND NOT stop_the_clock;
 



WB_DEV : wb_test
generic map(g_cnt_width => 32) 
port map(
		clk_i	=> s_clk_i,
		nRst_i	=> s_nRst_i,
		
		wb_slave_o     	=> s_wb_slave_o,	
		wb_slave_i     	=> s_wb_slave_i

    );


	s_master_IC_i <= wb32_master_in(s_wb_slave_o);
	s_wb_slave_i <= wb32_slave_in(s_master_IC_o);



	
pcapin : packet_capture
generic map(filename => "eb_input.pcap", wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,
rdy_o => rdy1,
	TOL_i	=> TOL,
	start_i => RST,
	packet_start_i		=> s_ebcore_i.CYC,
	valid_i			=> pcap_in_wren,
	data_i			=> s_ebcore_i.DAT
);

	pcap_in_wren <= (s_ebcore_i.STB AND (NOT s_ebcore_o.STALL));

pcapout : packet_capture
generic map(filename => "eb_output.pcap",  wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,
	rdy_o => rdy2,
	TOL_i	=> TOL,
	start_i => RST,
	packet_start_i		=> s_master_TX_stream_o.CYC,
	valid_i			=> pcap_out_wren,
	data_i			=> s_master_TX_stream_o.DAT
);		

pcap_out_wren <= (s_master_TX_stream_o.STB AND (NOT s_master_TX_stream_i.STALL));

clocked : process(s_clk_i)
begin
if (s_clk_i'event and s_clk_i = '1') then
		if(nRSt_i = '0') then
		else
			divider <= NOT divider;
			if(s_master_TX_stream_o.STB = '1') then
				bytecount <= bytecount + 2;
			end if;	
			stalled <=  s_ebcore_o.STALL;
			if(strobed = '0') then  
				strobed <= strobe AND NOT s_ebcore_o.STALL;
			else
				strobed <= NOT request	;
			end if;	
		end if;	
	end if;
end process;

s_master_TX_stream_i.STALL <= '0';--divider;



-- Jam : process
 
	-- begin 
		-- if(start_test = '1') then
			-- s_master_TX_stream_i.STALL <= '1';
			-- wait for clock_period;
			-- s_master_TX_stream_i.STALL <= '0';
			-- wait for clock_period;
		 
		-- end if;
	  
-- end process Jam;




    clkGen : process
    variable dead : integer := 50;
	
	begin 
      while 1=1 loop
         s_clk_i <= '0', '1' after clock_period / 2;
         wait for clock_period;
		 --divider
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
	
	   gen_packet : process
    

	    variable i : integer := 0;
	    variable wstart : std_logic_vector(31 downto 0) := x"10000000";
		variable rstart : std_logic_vector(31 downto 0) := x"20000000";
		variable rback : std_logic_vector(31 downto 0) := x"F0000000";
		variable flags : std_logic_vector(5 downto 0) := "000100";
		
		variable eth_hdr1 : ETH_HDR := INIT_ETH_HDR(x"D15EA5EDBEEF");
		variable ipv4_hdr1 : IPV4_HDR := INIT_IPV4_HDR(x"DEADBEEF");
		variable udp_hdr1 : UDP_HDR := INIT_UDP_HDR(x"EBD1");
		variable eb_hdr1 : EB_HDR := INIT_EB_HDR;
		variable hdr1_block : std_logic_vector((c_HDR_LEN+4)*8-1 downto 0); 
		
		variable word_cnt : natural := 0;
    
    begin

		wait until rising_edge(s_clk_i);

		nRst_i <= '0';
		wait for clock_period;
		nRst_i <= '1';

		wait for clock_period;
		
		gen_start <= '1';
		
		for i in 0 to c_PACKETS-1 loop
			eth_hdr1.DST 	:= x"ADD071AC00EB";
			ipv4_hdr1.DST	:= x"FFFFFFFF"; --x"ADD000EB"; 
			ipv4_hdr1.TOL	:= std_logic_vector(to_unsigned(tol1,16));
			ipv4_hdr1.SUM	:= (others => '0');
			ipv4_hdr1.SUM	:= calc_ip_chksum(ipv4_hdr1);
			udp_hdr1.MLEN 	:= std_logic_vector(to_unsigned(tol1-c_HDR_LEN+8,16));
			hdr1_block := to_std_logic_vector(eth_hdr1) & to_std_logic_vector(ipv4_hdr1) & to_std_logic_vector(udp_hdr1) & to_std_logic_vector(eb_hdr1); 
			
			for i in 0 to ((c_HDR_LEN+4)/2-1) loop
				pack1(pack1'left-i) <= hdr1_block(hdr1_block'left-(i*16) downto hdr1_block'length-((i+1)*16));
				wait for clock_period;
			end loop;
			word_cnt := (pack1'left-((c_HDR_LEN+4)/2));
			for i in 0 to c_CYCLES-1 loop
				-- first (1) => write,  then (0) => read !!! it's downto
				pack1 <= create_EB_CYC(pack1, word_cnt, cyc1rw(i)(1), cyc1rw(i)(0), flags, wstart, rstart, rback);
				
				word_cnt := word_cnt - 2*(1 + cyc1rw(i)(1) + cyc1rw(i)(0) + sign(cyc1rw(i)(1)) + sign(cyc1rw(i)(0)));
				wait for clock_period;
			end loop;
		
			gen_packet_start <= '1';
			wait until gen_rdy = '1'; 
			for i in pack1'left downto word_cnt+1 loop
			  pack_tmp <= pack1(i);
			  gen_strobe <= '1';
			  wait for clock_period;
			end loop;
			gen_packet_start <= '0';
			gen_strobe <= '0';
			wait for clock_period;
		end loop;
		
		
		gen_packet_start <= '0';
		gen_start <= '0';
		gen_strobe <= '0';

		wait for clock_period*20;
		start_test <= '1';
		wait;
	end process gen_packet;
	
	
	
	
    rx_packet : process
    
	
	    variable i : integer := 0;
	    
		variable packets : natural := 1;
		variable cycles : natural := 0;
		variable rds : natural := 0;
		variable wrs : natural := 0;
		
		variable txcount : natural := 0;
		variable datacount : natural := 0;
		variable buffersize : integer := 0;
		
    
    begin
        wait until rising_edge(start_test);
		
		wait until rising_edge(s_clk_i);
		
			while(packets>0) loop

		


			s_ebcore_i.WE 	<= '1';
			s_ebcore_i.CYC 	<= '1';
			capture <= '1';
			while(rdy = '0') loop
				wait for clock_period;
			end loop;	
			--request <= '1';
			while(rdy = '1') loop
				if(s_master_TX_stream_o.CYC = '1') then
					txcount := txcount+1;
				end if;
				if(s_master_TX_stream_o.STB = '1' AND s_master_TX_stream_i.STALL = '0') then
					datacount := txcount+2;
				end if;
				buffersize := txcount - datacount;
				if(buffersize > max_buffersize) then
					max_buffersize <= buffersize;
				end if;
					
				wait for clock_period;
			end loop;
			
			--request <= '0';
			s_ebcore_i.CYC 	<= '0';
			wait for 100*clock_period; 
			packets := packets -1;
		end loop;
		
		stop_the_clock <= '1';
		wait for 48*clock_period; 
		

		capture <= '0';



		wait;
	end process rx_packet;
	


end architecture behavioral;   


