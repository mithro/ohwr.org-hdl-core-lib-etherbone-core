--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.vhdl_2008_workaround_pkg.all;

use work.wb16_package.all;


entity packet_generator is 
end packet_generator;

architecture behavioral of packet_generator is


----------------------------------------------------------------------------------
constant c_PACKETS  : natural := 1;
constant c_CYCLES   : natural := 4;

type rws is array (0 to 1) of natural;
type rws_cycle is array (0 to c_CYCLES-1) of rws;

subtype flagvec is std_logic_vector(5 downto 0);
type flags_cycle is array(0 to c_CYCLES-1) of flagvec;

subtype word is std_logic_vector(15 downto 0); 
type eth_packet  is array (512 downto 0) of word;

constant c_READ_START 	: unsigned(31 downto 0) := x"0000000C";
constant c_REPLY_START	: unsigned(31 downto 0) := x"ADD3E550";

constant c_WRITE_START 	: unsigned(31 downto 0) := x"00000010";
constant c_WRITE_VAL	: unsigned(31 downto 0) := x"0000000F";

constant cyc1rw : rws_cycle := ((0, 1), (2, 3), (4, 5), (6, 7));
	signal pack1 : eth_packet := (others => (others => '0'));





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
			tmp := tmp + rd + wr + sign(rd) + sign(wr); -- cyc hdr, rd_back_adr, wr_start_adr
		end loop;
		output := output + (tmp * 4); -- 32b words
		
	return output;
end function calc_packet_length; 


function create_EB_CYC(packet : eth_packet; pPtr : natural; reads : natural; writes : natural; flags : std_logic_vector; wr_start : std_logic_vector; rd_start : std_logic_vector; rd_back : std_logic_vector)
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
		
		tmp.ADR_CFG 	:=	flags(5);
		tmp.RBA_CFG 	:= 	flags(4);
		tmp.RD_FIFO 	:=	flags(3);
		tmp.DROP_CYC 	:=  flags(2);
		tmp.WBA_CFG		:= 	flags(1);	
		tmp.WR_FIFO 	:=	flags(0);
		tmp.RD_CNT		:=	to_unsigned(reads,8);
		tmp.WR_CNT		:=	to_unsigned(writes,8);
		
		-- write EB cycle header
		tmp32b := to_std_logic_vector(tmp);
		tmp_packet(tmp_pPtr) := tmp32b(31 downto 16);
		tmp_pPtr := tmp_pPtr-1;
		tmp_packet(tmp_pPtr) := tmp32b(15 downto 0);
		tmp_pPtr := tmp_pPtr-1;
		
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
		
	return tmp_packet;
end function create_EB_CYC; 


function calc_ip_chksum(input : IPV4_HDR)
return std_logic_vector is
    variable tmp : unsigned(c_IPV4_HLEN-1 downto 0); 
	variable output : std_logic_vector(15 downto 0);
	variable tmp_sum : unsigned(31 downto 0) := (others => '0');
	variable tmp_slice : unsigned(15 downto 0);
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
signal start : std_logic;



signal pack_tmp : std_logic_vector(15 downto 0);




begin

pcapout : packet_capture
generic map(filename => "test_V4.pcap",  wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> nRst_i,

	TOL_i	=> word(to_unsigned(tol1,16)),
	
	sample_i		=> start,
	valid_i			=> strobe,
	data_i			=> pack_tmp
);		


clocked : process(s_clk_i)
begin
if (s_clk_i'event and s_clk_i = '1') then
		if(nRSt_i = '0') then
		else

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
    
	
	
    rx_packet : process
    

	    variable i : integer := 0;
	    variable wstart : std_logic_vector(31 downto 0) := x"10000000";
		variable rstart : std_logic_vector(31 downto 0) := x"10000000";
		variable rback : std_logic_vector(31 downto 0) := x"F0000000";
		variable flags : std_logic_vector(5 downto 0) := "000100";
		
		variable eth_hdr1 : ETH_HDR := INIT_ETH_HDR(x"D15EA5EDBEEF");
		variable ipv4_hdr1 : IPV4_HDR := INIT_IPV4_HDR(x"DEADBEEF");
		variable udp_hdr1 : UDP_HDR := INIT_UDP_HDR(x"EBD1");
		variable eb_hdr1 : EB_HDR := INIT_EB_HDR;
		variable hdr1_block : std_logic_vector((c_HDR_LEN+4)*8-1 downto 0); 
		
		variable word_cnt : natural := 0;
    
    begin

		eth_hdr1.DST 	:= x"ADD071AC00EB";
		ipv4_hdr1.DST	:= x"ADD000EB"; 
		ipv4_hdr1.TOL	:= std_logic_vector(to_unsigned(tol1,16));
		ipv4_hdr1.SUM	:= calc_ip_chksum(ipv4_hdr1);
		udp_hdr1.MLEN 	:= std_logic_vector(to_unsigned(tol1-c_HDR_LEN,16));
		hdr1_block := to_std_logic_vector(eth_hdr1) & to_std_logic_vector(ipv4_hdr1) & to_std_logic_vector(udp_hdr1) & to_std_logic_vector(eb_hdr1); 
		
		
		
		
		
		
		wait until rising_edge(s_clk_i);

		nRst_i <= '0';
		wait for clock_period;
		nRst_i <= '1';
		start <= '1';
		wait for clock_period;
		
		
--	valid_i			=> strobe,
--	data_i			=> pack_tmp
		
		
		
		for i in 0 to ((c_HDR_LEN+4)/2-1) loop
			pack1(pack1'left-i) <= hdr1_block(hdr1_block'left-(i*16) downto hdr1_block'length-((i+1)*16));
			wait for clock_period;
		end loop;
		word_cnt := (pack1'left-((c_HDR_LEN+4)/2));
		for i in c_CYCLES-1 downto 0 loop
			pack1 <= create_EB_CYC(pack1, word_cnt, cyc1rw(i)(0), cyc1rw(i)(1), flags, wstart, rstart, rback);
			
			word_cnt := word_cnt - 2*(1 + cyc1rw(i)(0) + cyc1rw(i)(1) + sign(cyc1rw(i)(0)) + sign(cyc1rw(i)(1)));
			wait for clock_period;
		end loop;
		
		for i in pack1'left downto word_cnt+1 loop
		  pack_tmp <= pack1(i);
		  strobe <= '1';
		  wait for clock_period;
		end loop;
		
		
		
		strobe <= '0';
		start <= '0';
		wait for 10*clock_period; 
		stop_the_clock <= '1';
		wait for 10*clock_period; 
		wait;
	end process rx_packet;
	


end architecture behavioral;   


