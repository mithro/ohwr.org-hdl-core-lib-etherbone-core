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

entity eb_2_wb_converter is
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
end eb_2_wb_converter;

architecture behavioral of eb_2_wb_converter is

constant c_width_int : integer := 24;
type st_rx is (IDLE, EB_HDR_REC, EB_HDR_PROC,  CYC_HDR_REC, CYC_HDR_READ_PROC, CYC_HDR_READ_GET_ADR, WB_READ_RDY, WB_READ, CYC_HDR_WRITE_PROC, CYC_HDR_WRITE_GET_ADR, WB_WRITE_RDY, WB_WRITE, CYC_DONE, EB_DONE, ERROR);
type st_tx is (IDLE, EB_HDR_INIT, PACKET_HDR_SEND, EB_HDR_SEND, RDY, CYC_HDR_INIT, CYC_HDR_SEND, BASE_WRITE_ADR_SEND, DATA_SEND, ZERO_PAD_WRITE, ZERO_PAD_WAIT, ERROR);

signal state_rx 		: st_rx := IDLE;
signal state_tx 		: st_tx := IDLE;

constant test : std_logic_vector(31 downto 0) := (others => '0');

signal RX_HDR 				: EB_HDR;
signal RX_HDR_SLV			: std_logic_vector(31 downto 0);
signal eb_hdr_rec_count 	: std_logic_vector(3 downto 0);
alias  eb_hdr_rec_done		: std_logic is eb_hdr_rec_count(eb_hdr_rec_count'left);

signal RX_CURRENT_CYC 		: EB_CYC;
signal RX_CURRENT_CYC_SLV	: std_logic_vector(31 downto 0);

signal TX_HDR 				: EB_HDR;
signal TX_HDR_SLV			: std_logic_vector(31 downto 0);
signal eb_hdr_send_count 	: std_logic_vector(3 downto 0);
alias  eb_hdr_send_done		: std_logic is eb_hdr_send_count(eb_hdr_send_count'left);

signal TX_CURRENT_CYC 		: EB_CYC;
signal TX_CURRENT_CYC_SLV	: std_logic_vector(31 downto 0);

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

signal WB_STB : std_logic;	
signal WB_ADR : std_logic_vector(master_IC_o.ADR'left downto 0);	
signal WB_CYC : std_logic;	
signal WB_WE : std_logic;	

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
												

component wb_test 
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wb32_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wb32_slave_in
    );
end component;

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


begin
								 
								 
slave_RX_stream_o.ACK 	<= RX_ACK;








WB_DEV : wb_test
generic map(g_cnt_width => 32) 
port map(
		clk_i	=> clk_i,
		nRst_i	=> nRst_i,
		
		wb_slave_o     	=> WB_Config_o,	
		wb_slave_i     	=> WB_Config_i

    );

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

master_TX_stream_o.STB 	<= NOT s_tx_fifo_empty;
s_tx_fifo_rd			<= NOT master_TX_stream_i.STALL;
s_tx_fifo_we			<= TX_STB AND NOT (s_tx_fifo_am_full);	
	
RX_FIFO : alt_FIFO_am_full_flag
port map(
		clock			=> clk_i,
		data			=> slave_RX_stream_i.DAT,
		rdreq			=> s_rx_fifo_rd,
		sclr			=> s_rx_fifo_clr,
		wrreq			=> s_rx_fifo_we,
		almost_empty	=> s_rx_fifo_am_empty,
		almost_full		=> s_rx_fifo_am_full,
		empty			=> s_rx_fifo_empty,
		full			=> s_rx_fifo_full,
		q				=>  s_rx_fifo_q,
		usedw			=> s_rx_fifo_gauge
	);	

s_WB_o.DAT 	<= s_rx_fifo_q;
s_WB_o.STB	<= WB_STB;	
s_WB_o.ADR	<= 	s_rx_fifo_q when state_rx = WB_READ
				else WB_ADR;	
s_WB_o.CYC  <= WB_CYC;	
s_WB_o.WE	<= WB_WE;	
	
slave_RX_stream_o.STALL <= s_rx_fifo_am_full; 



s_rx_fifo_we 			<= slave_RX_stream_i.STB AND NOT (s_rx_fifo_am_full);


--RX stall sources: mode write or read: internal, WB or TX when fifo (almost) full
--					otherwise only internal
--slave_RX_stream_STALL  	<= RX_STALL;-- OR s_WB_i.STALL OR (master_TX_stream_i.STALL AND (s_tx_fifo_am_full OR s_tx_fifo_full)) when (state_rx = WB_READ OR state_rx = WB_WRITE)
						--else RX_STALL;
	
	
-- select EB input path: Slave Config Block Out / WB Master Port In
WB_I_MUX_INTERNAL_REGISTERS : with s_ADR_CONFIG select
s_WB_i <=	WB_Config_o when '1',
		master_IC_i	when others;

-- select WB Master Port Out: Tie to ground / Signal s_WB_o
IC_O_MUX_INTERNAL_REGISTERS : with s_ADR_CONFIG select
master_IC_o <=	 WBM_Zero_o when '1',
						s_WB_o	 when others;

-- select Slave Config Block in: Signal s_WB_o / tie to ground
CONFIG_I_MUX_INTERNAL_REGISTERS : with s_ADR_CONFIG select
WB_Config_i <=	 s_WB_o 	when '1',
		WBM_Zero_o when others;		

		
		
		
debug_diff <= '1' when debug_byte_diff > 0 else '0';


count_io : process(clk_i)
begin
	if rising_edge(clk_i) then
		
		if (nRST_i = '0') then
			rx_eb_byte_count <= (others => '0');
			tx_eb_byte_count <= (others => '0');
			tx_zeropad_count <=  (others => '0');			
		else
			
			
			--Counter: RX bytes received
			if(state_rx = IDLE) then
				rx_eb_byte_count <= (others => '0');
			else
				if(slave_RX_stream_i.STB = '1' AND slave_RX_stream_STALL = '0') then
					rx_eb_byte_count <= rx_eb_byte_count + 4;	
				end if;
			end if;
			
			--Counter: WB ACKs received
			if(state_rx = IDLE) then
				ACK_COUNTER <= (others => '0');
			else
				if(state_rx = CYC_HDR_WRITE_PROC) then
					ACK_CNT 		<= RX_CURRENT_CYC.RD_CNT + RX_CURRENT_CYC.WR_CNT; 
				elsif(s_WB_i.ACK = '1') then
					ACK_CNT 				<= ACK_CNT -1;
				end if;
			end if;
			
			--Counter: TX bytes sent
			if(state_tx = IDLE) then
				tx_eb_byte_count <= (others => '0');
			else
				if(TX_STB = '1' AND master_TX_stream_i.STALL = '0') then
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
			
			RX_HDR_SLV  <= (others => '0');
			RX_CURRENT_CYC_SLV <= (others => '0');
			
			TX_HDR   <= init_EB_HDR;
			TX_CURRENT_CYC <= to_EB_CYC(test);
			TX_base_write_adr <= (others => '0');
			RX_CURRENT_CYC <= to_EB_CYC(test);
			
			RX_ACK <= '0';
			--s_WB_o 	<= WBM_Zero_o;
											
			master_TX_stream_o.CYC 	<= '0';
			
			master_TX_stream_o.ADR 	<= (others => '0');
			master_TX_stream_o.SEL 	<= (others => '1');
			master_TX_stream_o.WE  	<= '1';

			
			slave_RX_stream_o.ERR   <= '0';
			slave_RX_stream_o.RTY   <= '0';
			RX_STALL <= '0';
			slave_RX_stream_o.DAT   <= (others => '0');
			wb_addr_count           <= (others => '0');
			s_byte_count_rx_i		 <= (others => '0');
			s_ADR_CONFIG <=	'0';
			s_tx_fifo_clr <= '1';
			s_rx_fifo_clr <= '1';
			
			debugsum <= (others => '0');
			WB_STB <= '0';
			WB_WE <= '0';
			WB_ADR <= (others => '0');	
		else

			RX_ACK 				<= slave_RX_stream_i.STB AND NOT slave_RX_stream_STALL;
			
			s_rx_fifo_rd 		<= '0';	
			
			WB_STB <= '0';
			s_tx_fifo_clr 		<= '0';
			s_rx_fifo_clr 		<= '0';	
			
			
			 -- RX cycle line lowered before all words were transferred
			if	(rx_eb_byte_count < s_byte_count_rx_i
			AND  slave_RX_stream_i.CYC = '0' 
			AND (NOT (state_rx = IDLE OR state_rx = EB_HDR_REC))) then
				report "EB: PACKET WAS ABORTED" severity note;
			--	ERROR: -- RX cycle line lowered before all words were transferred
				state_rx 				<= IDLE;
				state_tx 				<= IDLE;
			
			else
			
				case state_rx is
					when IDLE 			=> 	state_tx 				<= IDLE;
											state_rx 				<= EB_HDR_REC;
											s_tx_fifo_clr <= '1';
											s_rx_fifo_clr <= '1';
											report "EB: RDY" severity note;
											

					when EB_HDR_REC		=> 	if(slave_RX_stream_i.CYC = '1' AND s_rx_fifo_empty = '0') then
												
												RX_HDR <= to_EB_HDR(s_rx_fifo_q);
												s_byte_count_rx_i <= unsigned(byte_count_rx_i) - c_HDR_LEN; -- Length - IPHDR - UDPHDR
												
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
												if(unsigned(s_rx_fifo_gauge) > 4) then
													state_tx <= EB_HDR_INIT;
													if(RX_HDR.PROBE = '0') then -- no probe, prepare cycle reception
														state_rx <= CYC_HDR_REC;
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
														state_rx <=  CYC_HDR_READ_PROC;
													end if;
												--end if;
					
					when CYC_HDR_WRITE_GET_ADR	=> 	if(s_rx_fifo_empty = '0') then
														wb_addr_count 	<= unsigned(s_rx_fifo_q);
														s_rx_fifo_rd 	<= '1'; -- only stall RX if we got an adress, otherwise continue listening
														state_rx 		<= WB_WRITE_RDY;
													end if;
													
					when WB_WRITE_RDY 	=>	if(state_tx = RDY) then
												WB_CYC 	<= '1';
												 -- only stall RX if we got an adress, otherwise continue listening
												--s_WB_o.DAT		<= s_rx_fifo_q;
												state_rx 			<= WB_WRITE;
												state_tx 			<= ZERO_PAD_WRITE;
												
											end if;		
					
					when WB_WRITE	=> 	if(RX_CURRENT_CYC.WR_CNT > 0 ) then --underflow of RX_cyc_wr_count
																					
												WB_ADR 		<= std_logic_vector(wb_addr_count);
												--s_WB_o.DAT		<= s_rx_fifo_q;
												WB_WE		<= '1';
												
													if((s_rx_fifo_am_empty = '0') AND (s_tx_fifo_am_full = '0')) then
														WB_STB  	<= '1';
														if(s_WB_i.STALL = '0') then
															s_rx_fifo_rd 	<= '1'; -- only stall RX if we got an adress, otherwise continue listening
														
															RX_CURRENT_CYC.WR_CNT 	<= RX_CURRENT_CYC.WR_CNT-1;
															wb_addr_count 			<= wb_addr_count + wb_addr_inc;
														end if;
													end if;
												
												
											
										else
											state_rx 				<= CYC_HDR_READ_PROC; 
										end if;
					
					when CYC_HDR_READ_PROC	=> 	if(state_tx = RDY) then
													--are there reads to do?
													if(RX_CURRENT_CYC.RD_CNT > 0) then
														--setup word counters
														s_ADR_CONFIG <=	RX_CURRENT_CYC.RCA_CFG;
														if(RX_CURRENT_CYC.RD_FIFO = '0') then
															wb_addr_inc <= to_unsigned(4, 32);
														else
															wb_addr_inc <= (others => '0');
														end if;
														state_tx 		<= CYC_HDR_INIT;
														state_rx 		<= CYC_HDR_READ_GET_ADR;
													else
														state_rx 		<=  CYC_DONE;
													end if;
													
												end if;
					
					when CYC_HDR_READ_GET_ADR	=>	if(s_rx_fifo_empty = '0') then
														--wait for ready from tx output
														TX_base_write_adr 	<= s_rx_fifo_q;
														s_rx_fifo_rd 	<= '1';
														state_rx 			<= WB_READ_RDY;
													end if;
													
													
					when WB_READ_RDY	=>			if(state_tx = RDY) then
														WB_CYC <= '1';
														
														state_rx 		<= WB_READ;
														state_tx 		<= BASE_WRITE_ADR_SEND;
														
													end if;

					when WB_READ	=>	if(RX_CURRENT_CYC.RD_CNT > 0) then 
											
											if(state_tx = DATA_SEND) then
											   
												WB_ADR 	<= s_rx_fifo_q;
												
												if((s_rx_fifo_empty = '0') AND (s_tx_fifo_am_full = '0')) then
														
														WB_STB  	<= '1';
														if(s_WB_i.STALL = '0') then
															s_rx_fifo_rd <= '1';
															RX_CURRENT_CYC.RD_CNT <= RX_CURRENT_CYC.RD_CNT-1;
														end if;
													end if;
												end if;
											
										else
											state_rx 				<= CYC_DONE;
										end if;

					

					when CYC_DONE	=>	if(ACK_CNT = 0 ) then
											--keep cycle line high if no drop requested
											WB_CYC <= NOT RX_CURRENT_CYC.DROP_CYC;
																						
											if(rx_eb_byte_count < s_byte_count_rx_i) then	
												state_rx 		<= CYC_HDR_REC;
											else
												--no more cycles to do, packet is done. reset FSMs
												state_rx 			<= EB_DONE;
												state_tx 			<= IDLE;
											end if;
										elsif(ACK_CNT_ERR = "1") then
											state_rx <= ERROR;
										end if;
										
					when EB_DONE 	=> report "EB: PACKET COMPLETE" severity note;  
										WB_CYC <= NOT RX_CURRENT_CYC.DROP_CYC;
										--make sure there is no running transfer before resetting FSMs, also do not start a new packet proc before cyc has been lowered
										if(state_tx = IDLE OR state_tx = RDY) then -- 1. packet done, 2. probe done
											state_rx <= IDLE;
											state_tx <= IDLE;
										end if;	


					when ERROR		=> 	report "EB: ERROR" severity warning;
										WB_CYC <= '0';
										state_tx 		<= IDLE;
										
										if((RX_HDR.VER 			/= c_EB_VER)				-- wrong version
											OR (RX_HDR.ADDR_SIZE 	/= c_MY_EB_ADDR_SIZE)					-- wrong size
											OR (RX_HDR.PORT_SIZE 	/= c_MY_EB_PORT_SIZE))	then
											state_tx <= ERROR;
										end if;
										state_rx <= IDLE;

					when others 	=> 	state_rx <= IDLE;
				end case;
			
			
			
				TX_STB <= '0';
				

				case state_tx is
					when IDLE 			=>  master_TX_stream_o.CYC <= '0';
											
					when RDY			=>	null;--wait
											
					when EB_HDR_INIT	=>	
											TX_HDR		<= init_EB_hdr;
											state_tx	<= PACKET_HDR_SEND;
					
					when PACKET_HDR_SEND	=> 	master_TX_stream_o.CYC <= '1';
												--using stall line for signalling the completion of Eth packet hdr
												state_tx <=  EB_HDR_SEND;
												
											

					
					when EB_HDR_SEND	=>	TX_STB <= '1';
											s_tx_fifo_data <= to_std_logic_vector(TX_HDR);
											if(s_tx_fifo_am_full = '0') then	
												
												if(RX_HDR.PROBE = '1') then
													state_tx <=  IDLE;
												else
													state_tx <=  RDY;
												end if;
											end if;
					
			
					
					
					when CYC_HDR_INIT	=>	TX_CURRENT_CYC.WCA_CFG 	<= RX_CURRENT_CYC.BCA_CFG;
											TX_CURRENT_CYC.RD_FIFO	<= '0';
											TX_CURRENT_CYC.RD_CNT	<= (others => '0');
											TX_CURRENT_CYC.WR_FIFO 	<= RX_CURRENT_CYC.RD_FIFO;
											TX_CURRENT_CYC.WR_CNT 	<= RX_CURRENT_CYC.RD_CNT;
											
											state_tx 				<= CYC_HDR_SEND;
											
					when CYC_HDR_SEND	=>	s_tx_fifo_data 	<= TO_STD_LOGIC_VECTOR(TX_CURRENT_CYC);
											TX_STB 					<= '1';
											if(s_tx_fifo_am_full = '0') then
												state_tx <=  RDY;
											end if;

					
			
					when BASE_WRITE_ADR_SEND => TX_STB 						<= '1';
												s_tx_fifo_data 		<= TX_base_write_adr;
												if(s_tx_fifo_am_full = '0') then
													state_tx 				<= DATA_SEND;
												end if;	
			
					when DATA_SEND		=>	--only write at the moment!
											if(TX_CURRENT_CYC.WR_CNT > 0) then 
												s_tx_fifo_data 	<= s_WB_i.DAT;
												TX_STB 			<= s_WB_i.ACK;
												
												if(s_WB_i.ACK = '1') then
													TX_CURRENT_CYC.WR_CNT 	<= TX_CURRENT_CYC.WR_CNT-1;
												end if;
											else
												state_tx <=  RDY;
											end if;
					
					when ZERO_PAD_WRITE =>	s_tx_fifo_data <= (others => '0');
											if(state_rx = wb_write) then
												TX_STB  				<= WB_STB AND NOT s_WB_i.STALL; -- ~ ACK, but without the latency
											else 	
												-- TODO: need to check for STALL of TX out (?)
												TX_STB   <= '1'; -- one more for rx base write address
												state_tx <= RDY;
											end if;	
											
					when ZERO_PAD_WAIT	=> 	null;
					
					when others 		=> 	state_tx <= IDLE;
				end case;
			
			end if;
			
		end if;
	end if;

end process;

end behavioral;