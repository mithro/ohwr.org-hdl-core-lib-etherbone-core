---! Standard library
library IEEE;
--! Standard packages
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages
use work.EB_HDR_PKG.all;
use work.wb32_package.all;
use work.vhdl_2008_workaround_pkg.all;

entity eb_mini_master is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;

		--Eth MAC WB Streaming signals
		slave_RX_stream_i	: in	wb32_slave_in;
		slave_RX_stream_o	: out	wb32_slave_out;

		master_TX_stream_i	: in	wb32_master_in;
		master_TX_stream_o	: out	wb32_master_out;

		byte_count_rx_i			: in std_logic_vector(15 downto 0);
		
		
		dst_MAC_o			: out  std_logic_vector(47 downto 0);
		dst_IP_o			: out  std_logic_vector(31 downto 0);
		dst_PORT_o			: out  std_logic_vector(15 downto 0);

		TOL_o				: out std_logic_vector(15 downto 0);
		
		hex_switch_i		: in std_logic_vector(3 downto 0);
		
		
		valid_o				: out std_logic

);
end eb_mini_master;

architecture behavioral of eb_mini_master is

constant c_width_int : integer := 24;
type st_rx is (IDLE, EB_HDR_REC, EB_HDR_PROC,  CYC_HDR_REC, CYC_HDR_READ_PROC, CYC_HDR_READ_GET_ADR, WB_READ_RDY, WB_READ, CYC_HDR_WRITE_PROC, CYC_HDR_WRITE_GET_ADR, WB_WRITE_RDY, WB_WRITE, CYC_DONE, EB_DONE, ERROR);
type st_tx is (IDLE, EB_HDR_INIT, PACKET_HDR_SEND, EB_HDR_SEND, RDY, CYC_HDR_INIT, CYC_HDR_SEND, BASE_WRITE_ADR_SEND, WR_DATA_SEND, READBACK_ADR_SEND, RD_DATA_SEND, CYC_DONE, EB_DONE, ERROR);


signal state_rx 		: st_rx := IDLE;
signal state_tx 		: st_tx := IDLE;

constant test : std_logic_vector(31 downto 0) := (others => '0');

signal RX_HDR 				: EB_HDR;
--signal RX_HDR_SLV			: std_logic_vector(31 downto 0);
--signal eb_hdr_rec_count 	: std_logic_vector(3 downto 0);
--alias  eb_hdr_rec_done		: std_logic is eb_hdr_rec_count(eb_hdr_rec_count'left);

signal RX_CURRENT_CYC 		: EB_CYC;
--signal RX_CURRENT_CYC_SLV	: std_logic_vector(31 downto 0);

signal TX_HDR 				: EB_HDR;
--signal TX_HDR_SLV			: std_logic_vector(31 downto 0);
--signal eb_hdr_send_count 	: std_logic_vector(3 downto 0);
--alias  eb_hdr_send_done		: std_logic is eb_hdr_send_count(eb_hdr_send_count'left);

signal TX_CURRENT_CYC 		: EB_CYC;
--signal TX_CURRENT_CYC_SLV	: std_logic_vector(31 downto 0);

signal wb_addr_inc 			: unsigned(c_EB_ADDR_SIZE_n-1 downto 0);
signal wb_addr_count			: unsigned(c_EB_ADDR_SIZE_n-1 downto 0);

signal rx_eb_byte_count 	: unsigned(15 downto 0);
signal tx_eb_byte_count 	: unsigned(15 downto 0);
signal debug_byte_diff		: unsigned(15 downto 0);
signal debug_diff : std_logic;
signal debugsum : unsigned(15 downto 0);

signal slave_RX_stream_STALL : std_logic;

signal tx_zeropad_count 	: unsigned(15 downto 0);

constant c_WB_WORDSIZE 	: natural := 32;
constant c_EB_HDR_LEN	: unsigned(3 downto 0) := x"0";

signal RX_ACK : std_logic;
signal RX_STALL : std_logic;
signal TX_STB : std_logic;


signal ACK_COUNTER : unsigned(8 downto 0); 
alias ACK_CNT : unsigned(7 downto 0) is ACK_COUNTER(7 downto 0);
alias ACK_CNT_ERR	: unsigned(0 downto 0) is ACK_COUNTER(8 downto 8);

signal sink_valid : std_logic;
signal TX_base_write_adr : std_logic_vector(31 downto 0);
signal s_byte_count_rx_i : unsigned(15 downto 0);

signal s_WB_i	: wb32_master_in;
signal s_WB_o	: wb32_master_out;

signal WB_Config_o	: wb32_slave_out;
signal WB_Config_i	: wb32_slave_in;

signal s_ADR_CONFIG : std_logic;

signal  s_status_en		: std_logic;
signal 	s_status_clr	: std_logic;

signal 	s_tx_fifo_am_full 	: std_logic;
signal 	s_tx_fifo_full 		: std_logic;
signal 	s_tx_fifo_am_empty 	: std_logic;
signal 	s_tx_fifo_empty 	: std_logic;
signal 	s_tx_fifo_data		: std_logic_vector(31 downto 0);
signal	s_tx_fifo_rd 		: std_logic;
signal	s_tx_fifo_clr 		: std_logic;
signal  s_tx_fifo_we 		: std_logic;
signal  s_tx_fifo_gauge		: std_logic_vector(3 downto 0);

signal 	s_rx_fifo_am_full 	: std_logic;
signal 	s_rx_fifo_full 		: std_logic;
signal 	s_rx_fifo_am_empty 	: std_logic;
signal 	s_rx_fifo_empty 	: std_logic;
signal 	s_rx_fifo_data		: std_logic_vector(31 downto 0);
signal 	s_rx_fifo_q		: std_logic_vector(31 downto 0);
signal	s_rx_fifo_rd 		: std_logic;
signal	s_rx_fifo_clr 		: std_logic;
signal  s_rx_fifo_we 		: std_logic;
signal  s_rx_fifo_gauge		: std_logic_vector(3 downto 0);

subtype dword is std_logic_vector(31 downto 0);
type init_mem is array (0 to 5) of dword ; 

type mem is array (0 to 7) of dword ; 
signal s_my_mem : mem;  

constant c_led_init : init_mem := (x"00000001", x"00000002", x"00000001", x"00000002", x"000000FF", x"0000001F");
--constant c_led_on : init_mem := (x"00000001", x"00000002", x"00000001", x"00000002", x"000000FF", x"000000DF");
signal s_init_cnt : natural;
signal s_tx_mode : std_logic;
signal s_rx_mode : std_logic;
signal s_hex_switch : unsigned(31 downto 0);
signal s_wr_ops : natural;
signal s_rd_ops : natural;

signal s_pattern_cnt : unsigned(3 downto 0);

signal s_packet_reception_complete : std_logic;


constant WBM_Zero_o		: wb32_master_out := 	(CYC => '0',
												STB => '0',
												ADR => (others => '0'),
												SEL => (others => '0'),
												WE  => '0',
												DAT => (others => '0'));
												
constant WBS_Zero_o		: wb32_slave_out := 	(ACK   => '0',
												ERR   => '0',
												RTY   => '0',
												STALL => '0',
												DAT   => (others => '0'));
												

component eb_config is 
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		status_i		: in 	std_logic;
		status_en		: in	std_logic;
		status_clr		: in	std_logic;
		
		wb_master_i     : in    wb32_master_in;
		wb_master_o     : out   wb32_master_out;	--! local Wishbone master lines
				
		wb_slave_o     : out   wb32_slave_out;	--! EB Wishbone slave lines
		wb_slave_i     : in    wb32_slave_in
    );
end component eb_config;

component alt_FIFO_am_full_flag IS
	PORT
	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		sclr		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		almost_empty		: OUT STD_LOGIC ;
		almost_full		: OUT STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q			: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
	);
end component alt_FIFO_am_full_flag;

signal   s_cycles_to_send		: natural := 0;
signal   c_cycles_to_send		: natural := 1;
constant c_test_wr_cnt			: natural := 8;
constant c_test_rd_cnt			: natural := 8;

signal 	 s_my_led_states		: natural := 0;
constant c_test_base_wr_adr 	: unsigned(31 downto 0) := x"00000000";

constant c_test_readback_adr	: unsigned(31 downto 0) := x"00000000";
constant c_test_read_start_adr	: unsigned(31 downto 0) := x"00000000"; 

signal	 s_wait_cnt : natural := 0;
constant c_wait_cnt : natural := 75000000;

signal clock_div : std_logic;
signal s_cycles_to_rx : natural;
signal v_add : natural;

begin
								 
						 
								 
slave_RX_stream_o.ACK 	<= RX_ACK;


TX_FIFO : alt_FIFO_am_full_flag
port map(
		clock			=> clk_i,
		data			=> s_tx_fifo_data,
		rdreq			=> s_tx_fifo_rd,
		sclr			=> s_tx_fifo_clr,
		wrreq			=> s_tx_fifo_we,
		almost_empty	=> s_tx_fifo_am_empty,
		almost_full		=> s_tx_fifo_am_full,
		empty			=> s_tx_fifo_empty,
		full			=> s_tx_fifo_full,
		q				=> master_TX_stream_o.DAT,
		usedw			=> s_tx_fifo_gauge
	);

--strobe out as long as there is data left	
--master_TX_stream_o.STB 	<= NOT(s_tx_fifo_empty OR (s_TX_STROBED AND master_TX_stream_i.STALL));
--next word if TX IF doesnt stall. underrun is caught internally
master_TX_stream_o.STB <= NOT s_tx_fifo_empty;

 
s_tx_fifo_rd			<= NOT master_TX_stream_i.STALL;
--write in pending data as long as there is space left
s_tx_fifo_we			<= TX_STB AND NOT s_tx_fifo_full;	
	
RX_FIFO : alt_FIFO_am_full_flag
port map(
		clock			=> clk_i,
		data			=> slave_RX_stream_i.DAT,
		rdreq			=> s_rx_fifo_rd,
		sclr			=> s_rx_fifo_clr,
		wrreq			=> s_rx_fifo_we,
		almost_empty	=> open,
		almost_full		=> s_rx_fifo_am_full,
		empty			=> s_rx_fifo_empty,
		full			=> s_rx_fifo_full,
		q				=>  s_rx_fifo_q,
		usedw			=> s_rx_fifo_gauge
	);	

--BUG: almost_empty flag is stuck after hitting empty repeatedly.
--create our own for now
s_rx_fifo_am_empty <= '1' when unsigned(s_rx_fifo_gauge) <= 1
			else '0';

slave_RX_stream_o.STALL <= s_rx_fifo_am_full; 



s_rx_fifo_we 			<= slave_RX_stream_i.STB AND NOT (s_rx_fifo_am_full OR s_packet_reception_complete);


		
		
		
debug_diff <= '1' when debug_byte_diff > 0 else '0';


count_io : process(clk_i)
begin
	if rising_edge(clk_i) then
		
		if (nRST_i = '0') then
			rx_eb_byte_count <= (others => '0');
		
		else
			
			
			--Counter: RX bytes received
			if(state_rx = IDLE) then
				rx_eb_byte_count <= (others => '0');
			else
				if(s_rx_fifo_we = '1') then
					rx_eb_byte_count <= rx_eb_byte_count + 4;	
				end if;
			end if;
			-- packet reception is not complete if min packet size not reached and < s_byte_count_rx_i
			-- 
			if((rx_eb_byte_count < s_byte_count_rx_i) OR (rx_eb_byte_count < 16)) then
				s_packet_reception_complete <= '0';
			else
				s_packet_reception_complete <= '1';
			end if;
		
			if(state_tx = IDLE) then
				tx_eb_byte_count <= (others => '0');
			else
				if(s_tx_fifo_we = '1') then
					tx_eb_byte_count <= tx_eb_byte_count + 4;
				end if;	
			end if;
			
			
		end if;
	end if;	
end process;


main: process(clk_i)



begin
	if rising_edge(clk_i) then

	   --==========================================================================
	   -- SYNC RESET
       --==========================================================================

		if (nRST_i = '0') then

			state_tx		<= IDLE;
			state_rx		<= IDLE;
			
			
			TX_HDR   <= init_EB_HDR;
			TX_CURRENT_CYC <= to_EB_CYC(test);
			TX_base_write_adr <= (others => '0');
			RX_CURRENT_CYC <= to_EB_CYC(test);
			
			RX_ACK <= '0';
			
											
			master_TX_stream_o.CYC 	<= '0';
			
			master_TX_stream_o.ADR 	<= (others => '0');
			master_TX_stream_o.SEL 	<= (others => '1');
			master_TX_stream_o.WE  	<= '1';

			
			slave_RX_stream_o.ERR   <= '0';
			slave_RX_stream_o.RTY   <= '0';
			RX_STALL <= '0';
			slave_RX_stream_o.DAT   <= (others => '0');
			wb_addr_count           <= (others => '0');
			s_byte_count_rx_i		<= (others => '0');
			s_ADR_CONFIG 			<=	'0';
			s_tx_fifo_clr 			<= '1';
			s_rx_fifo_clr 			<= '1';
			
			clock_div <= '0';
			
			dst_MAC_o			<= x"AABBCCDDEEFF";
			dst_IP_o			<= x"C0A80001";
			dst_PORT_o			<= x"EBD9";

			
		

			valid_o				<= '0';
			
			s_tx_mode <= '0';
			s_wr_ops <= 48;
			s_rd_ops <= 8;
			s_pattern_cnt <= (others => '0');
			s_init_cnt <= 0;
			TOL_o				<= (others => '0');
			s_cycles_to_send <= 1;
			s_cycles_to_rx <= 0;
			s_rx_mode <= '0';
		else
			
			s_hex_switch <= x"0000000" & unsigned(hex_switch_i);		
			
			RX_ACK 				<= slave_RX_stream_i.STB AND NOT slave_RX_stream_STALL;
			
			s_rx_fifo_rd 		<= '0';	
			s_tx_fifo_clr 		<= '0';
			s_rx_fifo_clr 		<= '0';	
			clock_div <= NOT clock_div;
			
			case state_rx is
					when IDLE 			=> 	s_rx_fifo_clr <= '1';
											
											if(s_rx_fifo_empty = '1') then
												state_rx 				<= EB_HDR_REC;
												
												report "EB: RDY" severity note;
											end if;
											
											

					when EB_HDR_REC		=> 	if(slave_RX_stream_i.CYC = '1' AND s_rx_fifo_empty = '0') then
												
												RX_HDR <= to_EB_HDR(s_rx_fifo_q);
												s_byte_count_rx_i <= unsigned(byte_count_rx_i) - 42; -- Length - IPHDR - UDPHDR
												
												s_rx_fifo_rd 		 	<= '1';	
												report "EB: PACKET START" severity note;
												state_rx 	<= EB_HDR_PROC;
											end if;
											

					when EB_HDR_PROC	=>	if(	(RX_HDR.EB_MAGIC /= c_EB_MAGIC_WORD) 	-- not EB
												OR 	(RX_HDR.VER /= c_EB_VER)				-- wrong version
												OR	((RX_HDR.ADDR_SIZE AND c_MY_EB_ADDR_SIZE) = x"0")					-- wrong size
												OR  ((RX_HDR.PORT_SIZE AND c_MY_EB_PORT_SIZE)= x"0"))					-- wrong size
											then
												state_rx <= ERROR;
											else
												--eb hdr seems valid, prepare answering packet. Wait for RX buffer not being empty 
												if(unsigned(s_rx_fifo_gauge) > 3) then
													
													if(RX_HDR.PROBE = '0') then -- no probe, prepare cycle reception
														state_rx <= CYC_HDR_REC;
														s_cycles_to_rx <= 0;
													else
														state_rx <= EB_DONE;	
													end if;	
												end if;
											end if;
										
					when CYC_HDR_REC	=> 	if(s_rx_fifo_empty = '0') then
													RX_CURRENT_CYC	<= TO_EB_CYC(s_rx_fifo_q);
													s_rx_fifo_rd <= '1';
													
													state_rx  <= CYC_HDR_WRITE_PROC;
													
											end if;
											

				
						
					when CYC_HDR_WRITE_PROC	=> 	if(RX_CURRENT_CYC.WR_CNT > 0) then
													--setup word counters
														s_ADR_CONFIG <=	RX_CURRENT_CYC.WCA_CFG;
														if(RX_CURRENT_CYC.WR_FIFO = '0') then
															wb_addr_inc  <= to_unsigned(4, 32);
														else
															wb_addr_inc  <= (others => '0');
														end if;							
														
														state_rx <=  CYC_HDR_WRITE_GET_ADR;
														
													else
														 -- only stall RX if we need time to check pending reads, otherwise get address
														
														state_rx 		<=  CYC_DONE;
													end if;
												--end if;
					
					when CYC_HDR_WRITE_GET_ADR	=> 	if(s_rx_fifo_am_empty = '0') then
														wb_addr_count 	<= unsigned(s_rx_fifo_q);
														s_rx_fifo_rd 	<= '1'; -- only stall RX if we got an adress, otherwise continue listening
														
														state_rx 		<= WB_WRITE_RDY;
													end if;
													
					when WB_WRITE_RDY 	=>	state_rx 			<= WB_WRITE;
											
													
					
					when WB_WRITE	=> 	if(RX_CURRENT_CYC.WR_CNT > 0 ) then --underflow of RX_cyc_wr_count
																					
												if(clock_div = '1') then
													if(s_rx_fifo_am_empty = '0') then
														
														
														
														s_rx_fifo_rd 	<= '1'; 
														RX_CURRENT_CYC.WR_CNT 	<= RX_CURRENT_CYC.WR_CNT-1;
														wb_addr_count 			<= wb_addr_count + 1;
														if(s_rx_mode = '0') then --init
															s_my_mem(to_integer(wb_addr_count)) <= s_rx_fifo_q;
														else
															s_my_mem(s_cycles_to_rx) <= s_rx_fifo_q;
														end if;	
														
													elsif(s_rx_fifo_empty = '0' AND (rx_eb_byte_count = s_byte_count_rx_i)) then
														s_rx_fifo_rd 	<= '1'; 
														if(s_rx_mode = '0') then --init
															s_my_mem(to_integer(wb_addr_count)) <= s_rx_fifo_q;
														else
															s_my_mem(s_cycles_to_rx) <= s_rx_fifo_q;
														end if;	
														RX_CURRENT_CYC.WR_CNT <= RX_CURRENT_CYC.WR_CNT-1;
														--WRITE TO ARRAY
													end if;
												end if;
										else
											state_rx 				<=  CYC_DONE;
											s_cycles_to_rx <= s_cycles_to_rx + 1;											
										end if;
					
					
					when CYC_DONE	=>	
										s_status_en		<= s_WB_i.ACK;
										if(rx_eb_byte_count < s_byte_count_rx_i ) then	
											state_rx 	<= CYC_HDR_REC;
										else
											--no more cycles to do, packet is done. reset FSMs
											if(s_rx_fifo_empty = '1') then
													state_rx 			<= EB_DONE;
											else
												state_rx 	<= CYC_HDR_REC;
											end if;
										end if;
										
										
					when EB_DONE 	=> report "EB: PACKET COMPLETE" severity note;  
										state_rx <= IDLE;
										s_rx_mode <= '1';
										


					when ERROR		=> 	report "EB: ERROR" severity warning;
	
										
										
										if((RX_HDR.VER 			/= c_EB_VER)				-- wrong version
											OR (RX_HDR.ADDR_SIZE 	/= c_MY_EB_ADDR_SIZE)					-- wrong size
											OR (RX_HDR.PORT_SIZE 	/= c_MY_EB_PORT_SIZE))	then
											
										end if;
										state_rx <= IDLE;

					when others 	=> 	state_rx <= IDLE;
				end case;
			
			
			
				TX_STB <= '0';
				valid_o				<= '0';
				
				if(clock_div = '1') then
				
				case state_tx is
					when IDLE 			=>  master_TX_stream_o.CYC <= '0';
											s_tx_fifo_clr <= '1';	
											s_wait_cnt <= c_wait_cnt;
											
											
											if(s_tx_fifo_empty = '1') then
												--- verdammt schlecht für synthese. multicycle ?
												TOL_o				<= std_logic_vector(to_unsigned(42 + ((1+ s_cycles_to_send * (1 + sign(s_wr_ops) +  s_wr_ops + sign(s_rd_ops) + s_rd_ops)) * 4), 16));
												
												
												
												valid_o				<= '1';
												state_tx <= EB_HDR_INIT;
												
											end if;	
											
				
											
					when EB_HDR_INIT	=>	TX_HDR		<= init_EB_hdr;
											state_tx	<= PACKET_HDR_SEND;
					
					when PACKET_HDR_SEND	=> 	master_TX_stream_o.CYC <= '1';
												--using stall line for signalling the completion of Eth packet hdr
												state_tx <=  EB_HDR_SEND;
												
											

					--TODO: padding to 64bit alignment
					when EB_HDR_SEND	=>	TX_STB <= '1';
											s_tx_fifo_data <= to_std_logic_vector(TX_HDR);
											if(s_tx_fifo_full = '0') then	
												state_tx 				<= CYC_HDR_INIT;
											end if;
					
			
					
					
					when CYC_HDR_INIT	=>	TX_CURRENT_CYC.WCA_CFG 	<= '0';
											TX_CURRENT_CYC.RD_FIFO	<= '0';
											
											TX_CURRENT_CYC.WR_FIFO 	<= '0';
											TX_CURRENT_CYC.WR_CNT 	<= to_unsigned(s_wr_ops, 8);
											TX_CURRENT_CYC.RD_CNT	<= to_unsigned(s_rd_ops, 8);
											
											s_init_cnt <= 0;
											
											state_tx 				<= CYC_HDR_SEND;
					 						
											
					when CYC_HDR_SEND	=>	s_tx_fifo_data 	<= TO_STD_LOGIC_VECTOR(TX_CURRENT_CYC);
											TX_STB 					<= '1';
											if(s_tx_fifo_full = '0') then
												if(TX_CURRENT_CYC.WR_CNT > 0) then
													state_tx <= BASE_WRITE_ADR_SEND;
												elsif(TX_CURRENT_CYC.RD_CNT > 0) then
													state_tx <= READBACK_ADR_SEND;
												else
													state_tx <= ERROR;
												end if;
											end if;

					when BASE_WRITE_ADR_SEND => TX_STB 						<= '1';
												if(s_tx_mode = '0') then --init
													s_tx_fifo_data 		<= std_logic_vector(c_test_base_wr_adr);
												else
													s_tx_fifo_data 		<= std_logic_vector(to_unsigned(((8-s_cycles_to_send) * 6 + 5), 30) & "00");
												end if;		
												if(s_tx_fifo_full = '0') then
													state_tx 				<= WR_DATA_SEND;
												end if;	
					
				
					
					
					when WR_DATA_SEND		=>	--only write at the moment!
											if(TX_CURRENT_CYC.WR_CNT > 0) then 
												---
												if(s_tx_mode = '0') then --init
													s_tx_fifo_data 	<= c_led_init(s_init_cnt);
													
												
													TX_STB 			<= '1';
													if(s_tx_fifo_full = '0') then	
														TX_CURRENT_CYC.WR_CNT 	<= TX_CURRENT_CYC.WR_CNT-1;
														if(s_init_cnt < 5) then
															s_init_cnt <= s_init_cnt + 1;
														else
															s_init_cnt <= 0;
														end if;		
													end if;
													
												
												
												
												
												else
													v_add <= 8-s_cycles_to_send;
													s_tx_fifo_data 	<= std_logic_vector(unsigned(s_my_mem(8-s_cycles_to_send)) + s_hex_switch) AND x"000000FF";
													
													TX_STB 			<= '1';
													if(s_tx_fifo_full = '0') then	
														TX_CURRENT_CYC.WR_CNT 	<= TX_CURRENT_CYC.WR_CNT-1;
														
													end if;
													
												end if;
												
												
											elsif(TX_CURRENT_CYC.RD_CNT > 0) then
												state_tx <= READBACK_ADR_SEND;
											else
												state_tx <= CYC_DONE;
												
												s_cycles_to_send <= s_cycles_to_send -1;
											end if;
											
					
					when READBACK_ADR_SEND 	=> 	TX_STB 				<= '1';
												s_tx_fifo_data 		<= std_logic_vector(c_test_readback_adr); 

												if(s_tx_fifo_full = '0') then
													state_tx 		<= RD_DATA_SEND;
												end if;	
			
					
					when RD_DATA_SEND		=>	--only write at the moment!
											if(TX_CURRENT_CYC.RD_CNT > 0) then 
												if(s_tx_mode = '0') then
													s_tx_fifo_data 		<= std_logic_vector(to_unsigned(((8-to_integer(TX_CURRENT_CYC.RD_CNT)) * 6 + 5), 30) & "00"); --s_my_led_states(to_integer(TX_CURRENT_CYC.RD_CNT(2 downto 0)-1));
												else
													s_tx_fifo_data 		<= std_logic_vector(to_unsigned(((8-s_cycles_to_send) * 6 + 5), 30) & "00"); --s_my_led_states(to_integer(TX_CURRENT_CYC.RD_CNT(2 downto 0)-1));
												
												end if;
												TX_STB 			<= '1';
												if(s_tx_fifo_full = '0') then
													TX_CURRENT_CYC.RD_CNT 	<= TX_CURRENT_CYC.RD_CNT-1;
												end if;	
											else
												state_tx <= CYC_DONE;
												
												s_cycles_to_send <= s_cycles_to_send -1;
											end if;
					
					when CYC_DONE 			=>	if(s_cycles_to_send > 0) then
													state_tx 				<= CYC_HDR_INIT;
												else 
													master_TX_stream_o.CYC <= '0';
													state_tx 				<= EB_DONE;
												end if;
					
					when EB_DONE			=> 	s_tx_mode <= '1';
												s_wr_ops <= 1;
												s_rd_ops <= 1;
												s_cycles_to_send <= 8;
											
												if(s_wait_cnt > 0) then
													s_wait_cnt <= s_wait_cnt -1;
												
												else
													--s_tx_mode <= NOT s_tx_mode;
													state_tx <= IDLE;
													
												end if;		
					
					when others 		=> 	state_tx <= EB_DONE;
				end case;
				end if;
			end if;
			
		end if;


end process;

end behavioral;