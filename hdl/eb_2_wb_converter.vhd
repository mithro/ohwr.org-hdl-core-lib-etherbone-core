---! Standard library
library IEEE;
--! Standard packages
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages
use work.EB_HDR_PKG.all;
use work.wishbone_package.all;

entity eb_2_wb_converter is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;

		--Eth MAC WB Streaming signals
		slave_RX_stream_i	: in	wishbone_slave_in;
		slave_RX_stream_o	: out	wishbone_slave_out;

		master_TX_stream_i	: in	wishbone_master_in;
		master_TX_stream_o	: out	wishbone_master_out;

		byte_count_rx_i			: in std_logic_vector(15 downto 0);
		
		--WB IC signals
		master_IC_i	: in	wishbone_master_in;
		master_IC_o	: out	wishbone_master_out

);
end eb_2_wb_converter;

architecture behavioral of eb_2_wb_converter is

constant c_width_int : integer := 24;
type st_rx is (IDLE, EB_HDR_REC, EB_HDR_PROC,  CYC_HDR_REC, CYC_HDR_READ_PROC, CYC_HDR_READ_GET_ADR, WB_READ_RDY, WB_READ, CYC_HDR_WRITE_PROC, CYC_HDR_WRITE_GET_ADR, WB_WRITE_RDY, WB_WRITE, CYC_DONE, EB_DONE, ERROR);
type st_tx is (IDLE, EB_HDR_INIT, EB_HDR_SEND, EB_HDR_DONE, CYC_HDR_INIT, CYC_HDR_SEND, CYC_HDR_DONE, BASE_WRITE_ADR_SEND, DATA_SEND, ZERO_PAD_WRITE, ZERO_PAD_WAIT, CYC_DONE, EB_DONE, ERROR);

signal state_rx 		: st_rx := IDLE;
signal state_tx 		: st_tx := IDLE;

signal slave_RX_stream_REG		: wishbone_slave_in;

signal RX_Stream_data_buff : std_logic_vector(31 downto 0);
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

signal tx_zeropad_count 	: unsigned(15 downto 0);

constant c_WB_WORDSIZE 	: natural := 32;
constant c_EB_HDR_LEN	: unsigned(3 downto 0) := x"0";

signal RX_ACK : std_logic;
signal RX_STALL : std_logic;
signal TX_STB : std_logic;
signal WB_STB : std_logic;

signal TX_base_write_adr : std_logic_vector(31 downto 0);
signal s_byte_count_rx_i : unsigned(15 downto 0);


begin


slave_RX_stream_o.ACK 	<= RX_ACK;
master_TX_stream_o.STB 	<= TX_STB;
slave_RX_stream_o.STALL  <= RX_STALL;
master_IC_o.STB <= WB_STB;

debug_diff <= '1' when debug_byte_diff > 0 else '0';


count_io : process(clk_i)
begin
	if rising_edge(clk_i) then
		if (nRST_i = '0') then
			rx_eb_byte_count <= (others => '0');
			tx_eb_byte_count <= (others => '0');
			tx_zeropad_count <=  (others => '0');			
		else
			--clear RX count on idle state, inc by 4byte if receiving on the bus
			if(state_rx = IDLE) then
				rx_eb_byte_count <= (others => '0');
			else
				--(slave_RX_stream_i.STB AND (NOT RX_STALL))
				if(RX_ACK = '1') then
					rx_eb_byte_count <= rx_eb_byte_count + 4;	
				end if;
			end if;
			
			--clear TX count on idle state, inc by 4byte if sending on the bus
			if(state_tx = IDLE) then
				tx_eb_byte_count <= (others => '0');
			else
				if(TX_STB = '1') then
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
			
			master_IC_o.CYC <= '0';
			
			master_IC_o.ADR 		<= (others => '0');
			master_IC_o.SEL 		<= (others => '1');
			master_IC_o.WE  		<= '0';
			master_IC_o.DAT 		<= (others => '0');
											
			master_TX_stream_o.CYC 	<= '0';
			
			master_TX_stream_o.ADR 	<= (others => '0');
			master_TX_stream_o.SEL 	<= (others => '1');
			master_TX_stream_o.WE  	<= '1';
			master_TX_stream_o.DAT 	<= (others => '0');
			
			slave_RX_stream_o.ERR   <= '0';
			slave_RX_stream_o.RTY   <= '0';
			RX_STALL <= '0';
			slave_RX_stream_o.DAT   <= (others => '0');
			wb_addr_count           <= (others => '0');
			s_byte_count_rx_i		 <= (others => '0');

			debugsum <= (others => '0');	
		else
			slave_RX_stream_REG 	<= slave_RX_stream_i;
			--RX_ACK 					<= '0';
			
			--RX_HDR 					<= TO_EB_HDR(RX_HDR_SLV);
			--RX_CURRENT_CYC  		<= TO_EB_CYC(RX_CURRENT_CYC_SLV);
			
			TX_HDR_SLV 				<= to_std_logic_vector(TX_HDR);

			master_IC_o.CYC <= '0';
			WB_STB <= '0';
			master_IC_o.WE	<= '0';
			master_IC_o.DAT	<= X"DEADBEEF";
			
			RX_STALL 	<=	'0';	
			RX_ACK <= (slave_RX_stream_i.STB AND (NOT RX_STALL));
			
			--ERROR: -- RX cycle line lowered before all words were transferred
			if	(rx_eb_byte_count < s_byte_count_rx_i
			AND  slave_RX_stream_i.CYC = '0' 
			AND (NOT (state_rx = IDLE OR state_rx = EB_HDR_REC))) then
				report "EB: PACKET WAS ABORTED" severity note;
				--ERROR: -- RX cycle line lowered before all words were transferred
				state_rx 				<= IDLE;
				state_tx 				<= IDLE;
			
			else
			
				case state_rx is
					when IDLE 			=> 	eb_hdr_rec_count 		<= std_logic_vector(c_EB_HDR_LEN);
											eb_hdr_send_count 		<= std_logic_vector(c_EB_HDR_LEN);
											debugsum <= debugsum + debug_byte_diff;
											debug_byte_diff <= (others => '0');
											state_tx 				<= IDLE;
											state_rx 				<= EB_HDR_REC;
											--slave_RX_stream_o.STALL 	<=	'0';
											report "EB: RDY" severity note;
											

					when EB_HDR_REC		=> 	
											  if(slave_RX_stream_i.CYC = '1' AND slave_RX_stream_i.STB = '1' AND slave_RX_stream_i.WE = '1') then
												--shift in
													--RX_ACK <= slave_RX_stream_i.STB;
													--RX_HDR_SLV <= RX_HDR_SLV((RX_HDR_SLV'LEFT - c_WB_WORDSIZE) downto 0) & slave_RX_stream_i.DAT;
													RX_HDR <= to_EB_HDR(slave_RX_stream_i.DAT);
													s_byte_count_rx_i <= unsigned(byte_count_rx_i) - 20 - 8; -- Length - IPHDR - UDPHDR
													eb_hdr_rec_count <= std_logic_vector(unsigned(eb_hdr_rec_count) - 1);
													RX_STALL 	<=	'1';		
													report "EB: PACKET START" severity note;
													state_rx <= EB_HDR_PROC;
												end if;
											

					when EB_HDR_PROC	=>	if(	(RX_HDR.EB_MAGIC /= c_EB_MAGIC_WORD) 	-- not EB
												OR 	(RX_HDR.VER /= c_EB_VER)				-- wrong version
												OR	((RX_HDR.ADDR_SIZE AND c_MY_EB_ADDR_SIZE) = x"0")					-- wrong size
												OR  ((RX_HDR.PORT_SIZE AND c_MY_EB_PORT_SIZE)= x"0"))					-- wrong size
											then
												state_rx <= ERROR;
											else
												--eb hdr seems valid, prepare answering packet 
												state_tx <= EB_HDR_INIT;
												if(RX_HDR.PROBE = '0') then -- no probe, prepare cycle reception
													
													state_rx <= CYC_HDR_REC;
												else
													state_rx <= EB_DONE;	
												end if;	
												
											end if;
										
					when CYC_HDR_REC	=> 	if(slave_RX_stream_i.STB = '1' AND slave_RX_stream_i.WE = '1') then
													RX_CURRENT_CYC	<= TO_EB_CYC(slave_RX_stream_i.DAT);
													RX_STALL <=	'1';
													state_rx <= CYC_HDR_READ_PROC;
													
											end if;
											

					when CYC_HDR_READ_PROC	=> 	RX_STALL 	<=	'1';
												--wait until TX is in a listening state
												if(state_tx = EB_HDR_DONE OR state_tx = CYC_DONE OR state_tx = CYC_HDR_DONE) then
													state_tx <= CYC_HDR_INIT;
													RX_STALL 	<=	'0';
													--are there reads to do?
													if(RX_CURRENT_CYC.RD_CNT > 0) then
														state_rx <= CYC_HDR_READ_GET_ADR;
														--setup word counters
														if(RX_CURRENT_CYC.RD_FIFO = '0') then
															wb_addr_inc  <= to_unsigned(4, 32);
														else
															wb_addr_inc  <= (others => '0');
														end if;
													else
														state_rx <=  CYC_HDR_WRITE_PROC;
													end if;
												
												end if;
						
				
					when CYC_HDR_READ_GET_ADR	=>	if(slave_RX_stream_i.STB = '1' AND slave_RX_stream_i.WE = '1') then
														--wait for ready from tx output
														TX_base_write_adr <= slave_RX_stream_i.DAT;
														RX_STALL <=	'1';
														state_rx <= WB_READ_RDY;
													end if;
													
													
					when WB_READ_RDY	=>			--wait until TX is in a listening state
													if(state_tx = CYC_HDR_DONE) then
														state_rx <= WB_READ;
														state_tx <=  BASE_WRITE_ADR_SEND;
														RX_STALL 	<=	'0';
													end if;

					when WB_READ	=>	--while there are read operations for the WB left ...
										if(RX_CURRENT_CYC.RD_CNT > 0) then 
											--WB Read
											master_IC_o.DAT 	<= x"5EADDA7A"; -- debugging only, unnessesary otherwise
											master_IC_o.ADR 	<= slave_RX_stream_i.DAT;
											WB_STB 	<= slave_RX_stream_i.STB;
											master_IC_o.CYC 	<= '1';
											
											--RX flow control
											RX_STALL <=	master_IC_i.STALL;
											if(slave_RX_stream_i.STB = '1') then
												RX_CURRENT_CYC.RD_CNT 	<= RX_CURRENT_CYC.RD_CNT-1;
											end if;
											
										else
											RX_STALL 	<=	'1';
											state_rx 			<=  CYC_HDR_WRITE_PROC;
										end if;

					when CYC_HDR_WRITE_PROC	=> 	RX_STALL 	<=	'1';
												--are there writes to do?
												if(RX_CURRENT_CYC.WR_CNT > 0) then
												--setup word counters
													if(RX_CURRENT_CYC.WR_FIFO = '0') then
														wb_addr_inc  <= to_unsigned(4, 32);
													else
														wb_addr_inc  <= (others => '0');
													end if;							
													
													state_rx <=  CYC_HDR_WRITE_GET_ADR;
													
												else
													state_rx <=  CYC_DONE;
												end if;
					
					when CYC_HDR_WRITE_GET_ADR	=> 	if(slave_RX_stream_i.STB = '1' AND slave_RX_stream_i.WE = '1') then
														wb_addr_count <= unsigned(slave_RX_stream_i.DAT);
														RX_STALL 	<=	'1';
														state_rx <= WB_WRITE_RDY;
													end if;
													
					when WB_WRITE_RDY 	=>		if(state_tx = CYC_HDR_DONE OR state_tx = CYC_DONE) then
														state_rx <= WB_WRITE;
														state_tx <=  ZERO_PAD_WRITE;
														RX_STALL 	<=	'0';
												end if;		
					
					when WB_WRITE	=> 	if(RX_CURRENT_CYC.WR_CNT > 0) then --underflow of RX_cyc_wr_count
											WB_STB 		<= slave_RX_stream_i.STB;
											master_IC_o.ADR 		<= std_logic_vector(wb_addr_count);
											master_IC_o.DAT			<= slave_RX_stream_i.DAT;
											master_IC_o.CYC 		<= '1';
											master_IC_o.WE			<= '1';
											--RX_ACK 					<= master_IC_i.ACK;
											--slave_RX_stream_o.STALL <=	'0';
											
											if(slave_RX_stream_i.STB = '1') then
												RX_CURRENT_CYC.WR_CNT 	<= RX_CURRENT_CYC.WR_CNT-1;
												wb_addr_count 			<= wb_addr_count + wb_addr_inc;
											end if;
										
										else
											RX_STALL <=	'1';
											state_rx <=  CYC_DONE;
										end if;

					when CYC_DONE	=>	--report "EB: CYCLE COMPLETE" severity note;
										RX_STALL <= '1';
										if(rx_eb_byte_count < s_byte_count_rx_i) then	
											if(state_tx = IDLE or state_tx = CYC_DONE OR state_tx = CYC_HDR_DONE) then 
												state_rx 		<= CYC_HDR_REC;
												
											end if;
										else
											--no more cycles to do, packet is done. reset FSMs
											state_rx 		<= EB_DONE;
											state_tx 		<= EB_DONE;
										end if;

					when EB_DONE 	=> report "EB: PACKET COMPLETE" severity note;  
										RX_STALL 	<=	'1';
										--make sure there is no running transfer before resetting FSMs, also do not start a new packet proc before cyc has been lowered
										if(state_tx = IDLE OR state_tx = EB_HDR_DONE OR state_tx = EB_DONE OR state_tx = CYC_HDR_DONE OR state_tx = CYC_DONE) then -- 1. packet done, 2. probe done
										--if(slave_RX_stream_i.CYC = '0' AND (state_tx = EB_HDR_DONE OR state_tx = EB_DONE OR state_tx = CYC_HDR_DONE OR state_tx = CYC_DONE)) then -- 1. packet done, 2. probe done
											debug_byte_diff	<= rx_eb_byte_count - tx_eb_byte_count;
											
											state_rx <= IDLE;
											state_tx <= IDLE;
										end if;	


					when ERROR		=> 	report "EB: ERROR" severity warning;
										if((RX_HDR.VER 			/= c_EB_VER)				-- wrong version
											OR (RX_HDR.ADDR_SIZE 	/= c_MY_EB_ADDR_SIZE)					-- wrong size
											OR (RX_HDR.PORT_SIZE 	/= c_MY_EB_PORT_SIZE))	then
											state_tx<= ERROR;
										end if;
										state_rx <= EB_DONE;

					when others 	=> 	state_rx <= IDLE;
				end case;
			
			
			
				TX_STB <= '0';
				

				case state_tx is
					when IDLE 			=>  master_TX_stream_o.CYC <= '0';
											

					when EB_HDR_INIT	=>	TX_HDR		<= init_EB_hdr;
											state_tx <=  EB_HDR_SEND;
												
												
					when EB_HDR_SEND	=>	master_TX_stream_o.CYC <= '1';
											if(eb_hdr_send_done = '0') then
												
												if(master_TX_stream_i.STALL = '0') then
												--shift in
													TX_STB <= '1';
													master_TX_stream_o.DAT <= TX_HDR_SLV(TX_HDR_SLV'LEFT downto TX_HDR_SLV'LENGTH - c_WB_WORDSIZE);
													TX_HDR_SLV <= TX_HDR_SLV(TX_HDR_SLV'LEFT - c_WB_WORDSIZE downto 0) & x"00000000";
													eb_hdr_send_count <= std_logic_vector(unsigned(eb_hdr_send_count) - 1);
												end if;
											else
												if(RX_HDR.PROBE = '1') then
													state_tx <=  EB_DONE;
												else
													state_tx <=  EB_HDR_DONE;
												end if;
											end if;

					when EB_HDR_DONE	=>	null; --wait;

					when CYC_HDR_INIT	=>	TX_CURRENT_CYC.RD_FIFO	<= '0';
											TX_CURRENT_CYC.RD_CNT	<= (others => '0');
											TX_CURRENT_CYC.WR_FIFO 	<= RX_CURRENT_CYC.RD_FIFO;
											TX_CURRENT_CYC.WR_CNT 	<= RX_CURRENT_CYC.RD_CNT;
											state_tx <= CYC_HDR_SEND;
											
					
					when CYC_HDR_SEND	=>	if(master_TX_stream_i.STALL = '0') then
												TX_STB <= '1';
												master_TX_stream_o.DAT <= TO_STD_LOGIC_VECTOR(TX_CURRENT_CYC);
												state_tx <= CYC_HDR_DONE;
											end if;

					when CYC_HDR_DONE	=>	null;--wait
			
					when BASE_WRITE_ADR_SEND => 	TX_STB 					<= '1';
													master_TX_stream_o.DAT 	<= TX_base_write_adr;
													state_tx <= DATA_SEND;
													
			
					when DATA_SEND		=>	--only write at the moment!
											if(TX_CURRENT_CYC.WR_CNT > 0) then 
												TX_STB <= master_IC_i.ACK;
												master_TX_stream_o.DAT <= master_IC_i.DAT;
												
												if(master_IC_i.ACK = '1') then
													TX_CURRENT_CYC.WR_CNT 	<= TX_CURRENT_CYC.WR_CNT-1;
												end if;
											else
												state_tx <= CYC_DONE;
											end if;
					
					when ZERO_PAD_WRITE =>	master_TX_stream_o.DAT <= (others => '0');
											if(state_rx = wb_write) then
												TX_STB  <= WB_STB AND NOT master_IC_i.STALL; -- ~ ACK, but without the latency
											elsif(state_rx = CYC_DONE) then	
												TX_STB  <= '1'; -- one more for the cycle hdr
												state_tx <= ZERO_PAD_WAIT;
											end if;	
											
					when ZERO_PAD_WAIT	=> state_tx <= CYC_DONE;
					
					when CYC_DONE		=>	null;
					
					
					
					
					when EB_DONE		=>	null;

					when others 		=> state_tx <= IDLE;
				end case;
			
			end if;
			
		end if;
	end if;

end process;

end behavioral;