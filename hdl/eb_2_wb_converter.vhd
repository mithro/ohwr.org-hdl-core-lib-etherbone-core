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
		
		--WB IC signals
		master_IC_i	: in	wishbone_master_in;
		master_IC_o	: out	wishbone_master_out

);
end eb_2_wb_converter;

architecture behavioral of eb_2_wb_converter is

constant c_width_int : integer := 24;


type st_main is (IDLE, BUSY);
type st_rx is (IDLE, EB_HDR_REC, EB_HDR_PROC,  CYC_HDR_REC, CYC_HDR_READ_PROC, WB_READ, CYC_HDR_WRITE_PROC, WB_WRITE, CYC_DONE, EB_DONE, ERROR);
type st_tx is (IDLE, EB_HDR_INIT, EB_HDR_SEND, CYC_HDR_INIT, CYC_HDR_SEND, DATA_SEND, WB_WRITE_INIT, WB_WRITE, CYC_DONE, EB_DONE, ERROR);

signal state_main 		: st_main := IDLE;
signal state_rx 		: st_rx := IDLE;
signal state_tx 		: st_tx := IDLE;

signal RX_HDR 			: EB_HDR;
signal RX_CURRENT_CYC 	: EB_CYC;

signal TX_HDR 			: EB_HDR;
signal TX_CURRENT_CYC 	: EB_CYC;

signal eb_word_count : unsigned(31 downto 0);

--signal status_cnt : unsigned := 0;

signal RX_Stream_data_buff : std_logic_vector(31 downto 0);

constant test : std_logic_vector(31 downto 0) := (others => '0');



begin

main: process(clk_i)
begin
	if rising_edge(clk_i) then

	   --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0') then
			RX_HDR			<= INIT_EB_HDR;	
			TX_HDR			<= INIT_EB_HDR;	
			TX_CURRENT_CYC	<= TO_EB_CYC(test);
			RX_CURRENT_CYC	<= TO_EB_CYC(test);
			state_main		<= IDLE;
			state_TX 		<= IDLE;
			state_RX 		<= IDLE;
		else
			
			case state_main is
				when IDLE 		=> 	state_tx 	<= IDLE;
									state_rX 	<= IDLE;
									if(slave_RX_stream_i.CYC = '1' AND slave_RX_stream_i.STB = '1') then 								
										--if(slave_RX_stream_i.DAT = c_EB_MAGIC_WORD) then -- found EB Hdr, start processing
											
											state_main 	<= BUSY;
									end if;	
				when BUSY  => 		case state_RX is
										when IDLE 			=> 	master_IC_o.CYC <= '0';
										when EB_HDR_REC		=> 	--if(RX_sh_reg_full = '1') then
																--RX_DATA = '1';	
															--else
																if(slave_RX_stream_i.CYC = '0') then -- cycle was interrupted before header was transmitted
																	state_RX <= ERROR;
																elsif(slave_RX_stream_i.STB = '0') then
																	--wait
																--	RX_sh_reg		<= '0';	
																else
																--	RX_sh_reg_we	<= '1';	
																end if;		
														--	end if;	
																--debug 
																state_rx 	<= EB_HDR_PROC;
																	
										when EB_HDR_PROC		=>	-- error handling - header
															if(	(RX_HDR.EB_MAGIC /= c_EB_MAGIC_WORD) 	-- not EB
															OR 	(RX_HDR.VER /= c_EB_VER)				-- wrong version	
															OR	(unsigned(RX_HDR.ADDR_SIZE) > 3)					-- wrong size
															OR  (unsigned(RX_HDR.PORT_SIZE) > 3))					-- wrong size
															then
																state_rx <= ERROR;
															else
																	
																state_tx <= EB_HDR_INIT;
																
															end if;
															
										when CYC_HDR_REC	=> 	if(RX_HDR.PROBE = '0') then
																	
																	slave_RX_stream_o.ACK 	<= slave_RX_stream_I.STB;
																	if(slave_RX_stream_I.STB = '1') then
																		RX_CURRENT_CYC	<= TO_EB_CYC(slave_RX_stream_I.DAT);
																		state_RX <= CYC_HDR_READ_PROC;
																	else
																		--wait
																	end if;
																else
																	state_RX <= EB_DONE;
																	state_TX <= EB_DONE;
																end if;
										when CYC_HDR_READ_PROC	=> 	-- if no cnt value > 0, this was just to probe us and is the last cycle
															if(state_TX = DATA_SEND) then --wait for ready from tx output
																state_RX <= WB_READ;
															else
																 -- eg 1 - 1 = 0, undeflow at -1 => 1 execution
																if(RX_CURRENT_CYC.RD_CNT > 0) then
																	--init cycle header
																	master_IC_o.CYC <= '1';
																	state_TX <= CYC_HDR_INIT;
																	
																	--setup word counters
																	if(RX_CURRENT_CYC.RD_FIFO = '1') then
																		--WB_M_ADDR_MUX <= CONST;
																	else
																		
																	end if;
																	
																else
																	state_RX <=  CYC_HDR_WRITE_PROC;	
																end if;	
															end if;
										
										when WB_READ	=>	--inc status cnt
															if(RX_CURRENT_CYC.RD_CNT = 0) then --underflow of RX_cyc_rd_count 	
																master_IC_o.ADR 		<= slave_RX_stream_i.DAT;
																master_IC_o.STB 		<= slave_RX_stream_i.STB;
																	
																slave_RX_stream_o.ACK 	<= master_IC_i.ACK;
																
																master_IC_o.DAT 		<= x"5EADDA7A"; -- debugging only, unnessesary otherwise
																
																if(master_IC_i.ACK = '1') then
																	RX_CURRENT_CYC.RD_CNT <= RX_CURRENT_CYC.RD_CNT-1;
																	eb_word_count 	<= eb_word_count+1;
																end if;	
															else		
																state_TX <=  CYC_DONE;
																state_RX <=  CYC_HDR_WRITE_PROC;
															end if;	
										
										when CYC_HDR_WRITE_PROC	=> 	if(RX_CURRENT_CYC.WR_CNT > 0) then
																	--setup word counters
																	if(RX_CURRENT_CYC.WR_FIFO = '1') then
																		--WB_M_ADDR_MUX <= CONST;
																	else
																		--WB_M_ADDR_MUX <= LIST; 
																	end if;
																	
																else
																	state_RX <=  CYC_DONE;
																end if;
																
										when WB_WRITE	=> 	if(RX_CURRENT_CYC.WR_CNT > 0) then --underflow of RX_cyc_wr_count 	
																master_IC_o.ADR 		<= slave_RX_stream_i.DAT;
																master_IC_o.STB 		<= slave_RX_stream_i.STB;
																slave_RX_stream_o.ACK 	<= master_IC_i.ACK;
																if(master_IC_i.ACK = '1') then
																	RX_CURRENT_CYC.WR_CNT <= RX_CURRENT_CYC.WR_CNT-1;
																	eb_word_count 	<= eb_word_count+1;
																end if;	
															else		
																state_RX <=  CYC_DONE;
															end if;	
										when CYC_DONE	=>	--another cycle to do?
															state_RX <= EB_DONE;
															--if() then
															--	state_RX <= CYC_HDR_REC;
															--else 	
										
										when EB_DONE 	=>  
															state_RX <= IDLE;
										
										when ERROR		=> if((RX_HDR.VER 			/= c_EB_VER)				-- wrong version	
															OR (RX_HDR.ADDR_SIZE 	/= c_EB_ADDR_SIZE)					-- wrong size
															OR (RX_HDR.PORT_SIZE 	/= c_EB_PORT_SIZE))	then
																state_TX <= ERROR; 
															end if;			
															state_RX <= EB_DONE;
											
										when others 	=> state_main <= IDLE;
									end case;
									
									
									master_TX_stream_o.STB <= '0';		
									
									case state_TX is
										when IDLE 			=> 
										
										when EB_HDR_INIT		=>	TX_HDR				<= INIT_EB_HDR;
																	
										when EB_HDR_SEND		=>	master_TX_stream_o.CYC <= '1';
																master_TX_stream_o.STB <= '1';
																master_TX_stream_o.DAT <= TO_STD_LOGIC_VECTOR(TX_HDR);
																if(RX_HDR.PROBE = '1') then
																  state_TX <=  EB_DONE;
																end if;
																
										when CYC_HDR_INIT	=>	TX_CURRENT_CYC.RD_FIFO	<= '0';
																TX_CURRENT_CYC.RD_CNT	<= (others => '0');
																TX_CURRENT_CYC.WR_FIFO 	<= RX_CURRENT_CYC.RD_FIFO;
																TX_CURRENT_CYC.WR_CNT 	<= RX_CURRENT_CYC.RD_CNT;
																state_TX <= CYC_HDR_SEND;
										when CYC_HDR_SEND	=>	--
																master_TX_stream_o.STB <= '1';
																master_TX_stream_o.DAT <= TO_STD_LOGIC_VECTOR(TX_CURRENT_CYC);
										          		state_TX <= DATA_SEND;				
										
										when DATA_SEND	=>	--only write at the moment!
																master_TX_stream_o.STB <= master_IC_i.ACK;	
																master_TX_stream_o.DAT <= master_IC_i.DAT;	
										
										when CYC_DONE		=>	
										
																	
										when EB_DONE		=>	master_TX_stream_o.CYC <= '0';
										
										when others 		=> state_main <= IDLE;
									end case;
									
				when others		=>	state_main <= IDLE;							
			end case;	
					
					
			
			
		end if;
	end if;    
	
end process;

end behavioral;