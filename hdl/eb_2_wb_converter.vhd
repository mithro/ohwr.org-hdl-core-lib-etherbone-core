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

		byte_count_rx_i			: in unsigned(15 downto 0);
		byte_count_tx_o   : out unsigned(15 downto 0);
		
		--WB IC signals
		master_IC_i	: in	wishbone_master_in;
		master_IC_o	: out	wishbone_master_out

);
end eb_2_wb_converter;

architecture behavioral of eb_2_wb_converter is


constant c_width_int : integer := 24;


type st_rx is (IDLE, EB_HDR_REC, EB_HDR_PROC,  CYC_HDR_REC, CYC_HDR_READ_PROC, CYC_HDR_READ_GET_ADR, WB_READ, CYC_HDR_WRITE_PROC, CYC_HDR_WRITE_GET_ADR, WB_WRITE, CYC_DONE, EB_DONE, ERROR);
type st_tx is (IDLE, EB_HDR_INIT, EB_HDR_SEND, EB_HDR_DONE, CYC_HDR_INIT, CYC_HDR_SEND, CYC_HDR_DONE, BASE_WRITE_ADR_SEND, DATA_SEND, CYC_DONE, EB_DONE, ERROR);

signal state_rx 		: st_rx := IDLE;
signal state_tx 		: st_tx := IDLE;


--registering this is necessary to have advanced knownledge of flow control signals
--use original signals for FSM control, use registered signals for all data processing 
signal slave_RX_stream_REG		: wishbone_slave_in;


--signal status_cnt : unsigned := 0;

signal RX_Stream_data_buff : std_logic_vector(31 downto 0);

constant test : std_logic_vector(31 downto 0) := (others => '0');

--TODO
--regs lshift for RX_HDR, RX_CURRENT_CYC
-- ---  MSB ... LSB <--

--TODO
--regs lshift for TX_HDR, TX_CURRENT_CYC
-- <--	MSB ... LSB ---



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
signal tx_zeropad_count 	: unsigned(15 downto 0);

constant c_WB_WORDSIZE 	: natural := 32;
constant c_EB_HDR_LEN	: unsigned(3 downto 0) := x"0";

signal RX_ACK : std_logic;
signal RX_STALL : std_logic;
signal TX_STB : std_logic;

signal TX_base_write_adr : std_logic_vector(31 downto 0);


begin


slave_RX_stream_o.ACK 	<= RX_ACK;
master_TX_stream_o.STB 	<= TX_STB;
slave_RX_stream_o.STALL  <= RX_STALL;


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
			
			--clear TX count on idle state, inc by 4byte if sending on the bus
			if(state_tx = EB_HDR_DONE OR state_tx = CYC_DONE) then
				tx_zeropad_count <= (others => '0');
			else
				if(TX_STB = '1' AND state_tx = ) then
					tx_zeropad_count <= tx_zeropad_count + 1;
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
			
		else
			slave_RX_stream_REG 	<= slave_RX_stream_i;
			--RX_ACK 					<= '0';
			
			--RX_HDR 					<= TO_EB_HDR(RX_HDR_SLV);
			--RX_CURRENT_CYC  		<= TO_EB_CYC(RX_CURRENT_CYC_SLV);
			
			TX_HDR_SLV 				<= to_std_logic_vector(TX_HDR);

			master_IC_o.CYC <= '0';
			master_IC_o.STB <= '0';
			master_IC_o.WE	<= '0';
			master_IC_o.DAT	<= X"DEADBEEF";
			
			RX_STALL 	<=	'0';	
			RX_ACK <= (slave_RX_stream_i.STB AND (NOT RX_STALL));
			
			case state_rx is
				when IDLE 			=> 	eb_hdr_rec_count 		<= std_logic_vector(c_EB_HDR_LEN);
										eb_hdr_send_count 		<= std_logic_vector(c_EB_HDR_LEN);
										state_tx 				<= IDLE;
										state_rx 				<= EB_HDR_REC;
										--slave_RX_stream_o.STALL 	<=	'0';
										

				when EB_HDR_REC		=> 	report "EB: RDY" severity note;
										if(eb_hdr_rec_done = '0') then
										  if(slave_RX_stream_i.STB = '1' AND slave_RX_stream_i.WE = '1') then
											--shift in
												--RX_ACK <= slave_RX_stream_i.STB;
												--RX_HDR_SLV <= RX_HDR_SLV((RX_HDR_SLV'LEFT - c_WB_WORDSIZE) downto 0) & slave_RX_stream_i.DAT;
												RX_HDR <= to_EB_HDR(slave_RX_stream_i.DAT);
												
												eb_hdr_rec_count <= std_logic_vector(unsigned(eb_hdr_rec_count) - 1);
												RX_STALL 	<=	'1';		
												state_rx <= EB_HDR_PROC;
											end if;
										else
				              	--slave_RX_stream_o.STALL 	<=	'1';						
											--state_rx <= EB_HDR_PROC;
										end if;

				when EB_HDR_PROC	=>	if(	(RX_HDR.EB_MAGIC /= c_EB_MAGIC_WORD) 	-- not EB
											OR 	(RX_HDR.VER /= c_EB_VER)				-- wrong version
									--		OR	((RX_HDR.ADDR_SIZE AND c_MY_EB_ADDR_SIZE) = x"0")					-- wrong size
											OR  ((RX_HDR.PORT_SIZE AND c_MY_EB_PORT_SIZE)= x"0"))					-- wrong size
										then
											state_rx <= ERROR;
										else
											--eb hdr seems valid, get cycle 
											state_rx <= CYC_HDR_REC;
											state_tx <= EB_HDR_INIT;
										end if;
									
				when CYC_HDR_REC	=> 	--slave_RX_stream_o.STALL <=	'0';	
										if(RX_HDR.PROBE = '0') then
											--RX_ACK 	<= slave_RX_stream_i.STB;
											if(slave_RX_stream_i.STB = '1' AND slave_RX_stream_i.WE = '1') then
												RX_CURRENT_CYC	<= TO_EB_CYC(slave_RX_stream_i.DAT);
												RX_STALL 	<=	'1';	
												state_rx <= CYC_HDR_READ_PROC;
											end if;
										else
											--this is a probe packet. just send back an eb hdr, no cycles.
											state_rx <= EB_DONE;
											state_tx <= EB_HDR_SEND;
										end if;

				when CYC_HDR_READ_PROC	=> 	-- if no cnt value > 0, this was just to probe us and is the last cycle
										RX_STALL 	<=	'1';
											
										
										-- eg 1 - 1 = 0, undeflow at -1 => 1 execution
										if(RX_CURRENT_CYC.RD_CNT > 0) then
											--wait for packet hdr, init cycle header
											if(state_tx = EB_HDR_INIT) then
												--if there are read cycles, send a hdr on tx 
												state_tx <= EB_HDR_SEND;
											elsif(state_tx = EB_HDR_DONE OR state_tx = CYC_DONE) then
											
											if(RX_CURRENT_CYC.WR_CNT > 0)
											
												--if tx is rdy waiting for data to send out, either after an 
												--eb hdr or a cyc hdr, continue 
											
												RX_STALL 	<=	'0';
												state_rx <= CYC_HDR_READ_GET_ADR; 
												state_tx <=  CYC_HDR_INIT;
											end if;	
											--setup word counters
											if(RX_CURRENT_CYC.RD_FIFO = '0') then
												wb_addr_inc  <= to_unsigned(4, 32);
											else
												wb_addr_inc  <= (others => '0');
											end if;

										else
											state_rx <=  CYC_HDR_WRITE_PROC;
										end if;

					
			
				when CYC_HDR_READ_GET_ADR	=>	
												--RX_ACK 					<= '1';
												if(state_tx = CYC_HDR_DONE) then
													state_rx <= WB_READ;
													state_tx <=  BASE_WRITE_ADR_SEND;
													RX_STALL 	<=	'0';
												else
													if(slave_RX_stream_i.STB = '1' AND slave_RX_stream_i.WE = '1') then
														--wait for ready from tx output
														TX_base_write_adr <= slave_RX_stream_i.DAT;
														
														RX_STALL <=	'1';
													end if;
												end if; 

				when WB_READ	=>	if(RX_CURRENT_CYC.RD_CNT > 0) then --underflow of RX_cyc_rd_count
										--WB Read
										master_IC_o.DAT 	<= x"5EADDA7A"; -- debugging only, unnessesary otherwise
										master_IC_o.ADR 	<= slave_RX_stream_i.DAT;
										master_IC_o.STB 	<= slave_RX_stream_i.STB;
										master_IC_o.CYC 	<= '1';
										
										--RX_ACK 	          	<= master_IC_i.ACK;
										
										--RX flow control
										RX_STALL <=	master_IC_i.STALL;
										

										if(slave_RX_stream_i.STB = '1') then
											RX_CURRENT_CYC.RD_CNT 	<= RX_CURRENT_CYC.RD_CNT-1;
										end if;
										
										--if(RX_CURRENT_CYC.RD_CNT-1 = 0) then
										--	RX_STALL <=	'1';
										-- end if;
									else
										RX_STALL 	<=	'1';
										state_rx 			<=  CYC_HDR_WRITE_PROC;
										
									end if;

				when CYC_HDR_WRITE_PROC	=> 	
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
													wb_addr_count 	<= unsigned(slave_RX_stream_i.DAT);
													--RX_ACK 			<= '1';
													state_rx 		<=  WB_WRITE;
												end if;
														
				when WB_WRITE	=> 	if(RX_CURRENT_CYC.WR_CNT > 0) then --underflow of RX_cyc_wr_count
										master_IC_o.STB 		<= slave_RX_stream_i.STB;
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
										
										-- if(RX_CURRENT_CYC.WR_CNT-1 = 0) then
											-- RX_STALL <=	'1';
										-- end if;
								
									else
										RX_STALL 	<=	'1';
										state_rx <=  CYC_DONE;
									end if;

				when CYC_DONE	=>	--report "EB: CYCLE COMPLETE" severity note;
									if(rx_eb_byte_count < byte_count_rx_i) then	
										if(state_tx = IDLE or state_tx = CYC_DONE) then
											state_rx 		<= CYC_HDR_REC;
										end if;
									else
										--no more cycles to do, packet is done. reset FSMs
										state_rx 		<= EB_DONE;
										state_tx 		<= EB_DONE;
									end if;

				when EB_DONE 	=> report "EB: PACKET COMPLETE" severity note;  
									RX_STALL 	<=	'1';
									--make sure there is no running transfer before resetting FSMs
									if(state_tx = IDLE OR state_tx = EB_HDR_DONE) then -- 1. packet done, 2. probe done
										state_rx <= IDLE;
									end if;	


				when ERROR		=> 	if((RX_HDR.VER 			/= c_EB_VER)				-- wrong version
										OR (RX_HDR.ADDR_SIZE 	/= c_MY_EB_ADDR_SIZE)					-- wrong size
										OR (RX_HDR.PORT_SIZE 	/= c_MY_EB_PORT_SIZE))	then
										state_tx<= ERROR;
									end if;
									state_rx <= EB_DONE;

				when others 	=> 	state_rx <= IDLE;
			end case;

			TX_STB <= '0';
			master_TX_stream_o.CYC <= '0';

			case state_tx is
				when IDLE 			=>  null;

				when EB_HDR_INIT	=>	TX_HDR		<= init_EB_hdr;
										--state_tx 	<= EB_HDR_SEND;
											
											
				when EB_HDR_SEND	=>	if(eb_hdr_send_done = '0') then
											master_TX_stream_o.CYC <= '1';
											if(master_TX_stream_i.STALL = '0') then
											--shift in
												TX_STB <= '1';
												master_TX_stream_o.DAT <= TX_HDR_SLV(TX_HDR_SLV'LEFT downto TX_HDR_SLV'LENGTH - c_WB_WORDSIZE);
												TX_HDR_SLV <= TX_HDR_SLV(TX_HDR_SLV'LEFT - c_WB_WORDSIZE downto 0) & x"00000000";
												eb_hdr_send_count <= std_logic_vector(unsigned(eb_hdr_send_count) - 1);
												tx_eb_byte_count <= tx_eb_byte_count + c_WB_WORDSIZE;
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
										if(RX_CURRENT_CYC.WR_CNT > 0) then
											state_tx <= ZERO_PAD_READS;	
										else
											state_tx <= CYC_HDR_SEND;
										end if;
				
				when ZERO_PAD_READS	=>	master_TX_stream_o.DAT <= (others => '0');
										if(tx_zeropad_count = RX_CURRENT_CYC.WR_CNT) then -- count to WR_CNT +1
											state_tx <= CYC_HDR_SEND;
										end if;	
										
				
				when CYC_HDR_SEND	=>	if(master_TX_stream_i.STALL = '0') then
											TX_STB <= '1';
											master_TX_stream_o.DAT <= TO_STD_LOGIC_VECTOR(TX_CURRENT_CYC);
											tx_eb_byte_count 			<= tx_eb_byte_count + c_WB_WORDSIZE;
											state_tx <= CYC_HDR_DONE;
										end if;

				when CYC_HDR_DONE	=>	null;--wait
        
				when BASE_WRITE_ADR_SEND => 	TX_STB 					<= '1';
												master_TX_stream_o.DAT 	<= TX_base_write_adr;
												tx_eb_byte_count 			<= tx_eb_byte_count + c_WB_WORDSIZE;
												state_tx <= DATA_SEND;
												
        
				when DATA_SEND		=>	--only write at the moment!
										if(TX_CURRENT_CYC.WR_CNT > 0) then 
											TX_STB <= master_IC_i.ACK;
											master_TX_stream_o.DAT <= master_IC_i.DAT;
											
											if(master_IC_i.ACK = '1') then
												TX_CURRENT_CYC.WR_CNT 	<= TX_CURRENT_CYC.WR_CNT-1;
												tx_eb_byte_count 		<= tx_eb_byte_count + c_WB_WORDSIZE;
											end if;
										else
											state_tx <= CYC_DONE;
										end if;

				when CYC_DONE		=>	null;
				
				when EB_DONE		=>	master_TX_stream_o.CYC <= '0';
										state_tx <= IDLE;

				when others 		=> state_tx <= IDLE;
			end case;

		end if;
	end if;

end process;

end behavioral;