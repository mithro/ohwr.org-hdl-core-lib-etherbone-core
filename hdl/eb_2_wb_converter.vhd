---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;

entity is EB_2_WB
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;
		
		--Eth MAC WB Streaming signals
		slave_RX_stream_i	: in	wishbone_slave_in;
		slave_RX_stream_o	: out	wishbone_slave_out
		
		master_TX_stream_i	: in	wishbone_master_in;
		master_TX_stream_o	: out	wishbone_master_out
		
		--WB IC signals
		master_IC_i	: in	wishbone_master_in;
		master_IC_o	: out	wishbone_master_out

);
end entity;

architecture behavioral of is

constant c_width_int : integer := 24;

type st is (IDLE, ADDUP, CARRIES, FINALISE, OUTPUT);

signal state 		: st := IDLE;

signal RX_HDR 			: EB_HDR;
signal RX_CURRENT_CYC 	: EB_CYC;

signal TX_HDR 			: EB_HDR;
signal TX_CURRENT_CYC 	: EB_CYC;

signal status_cnt : unsigned := 0;

signal RX_Stream_data_buff : std_logic_vector(31 downto 0);





begin

shift_in : piso_sreg_gen
generic map (EB_RX'LENGTH) -- size is IPV4+UDP+EB
port map (

        clk_i  => clk_i,                                        --clock
        nRST_i => nRST_i,
        en_i   => en,                        --shift enable        
        ld_i   => ld,                            --parallel load
        d_i    => p_in,        --parallel in
        q_o    => s_slv16_o                            --serial out
);




main: process(clk_i)
begin
	if rising_edge(clk_i) then

	   --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0') then
			RX_HDR			= INIT_EB_HDR;	
			TX_HDR			= INIT_EB_HDR;	
			TX_CURRENT_CYC	= TO_EB_CYC(others => '0');
			RX_CURRENT_CYC	= TO_EB_CYC(others => '0');
			state_main		= IDLE;
			state_TX 		= IDLE;
			state_RX 		= IDLE;
			RX_sh_reg		<= '0';	
		else
			
			case state_main is
				when IDLE 		=> 	state_TX 	= IDLE;
									state_RX 	= IDLE;
									if(slave_RX_stream_i.CYC = '1' AND slave_RX_stream_i.STB = '1') then 								
										if(slave_RX_stream_i.DAT = c_EB_MAGIC_WORD) then -- found EB Hdr, start processing
											
											state_main 	<= BUSY;
											RX_sh_reg	<= '1';	
									end if;	
				when BUSY  => 		case state_RX is
										when IDLE 		=> 
										when HDR_REC		=> 	if(RX_sh_reg_full = '1') then
																RX_DATA = '1';	
															else
																if(slave_RX_stream_i.CYC = '0') then -- cycle was interrupted before header was transmitted
																	state_RX <= ERROR;
																elsif(slave_RX_stream_i.STB = '0') then
																	--wait
																	RX_sh_reg		<= '0';	
																else
																	RX_sh_reg_we	<= '1';	
																end if;		
															end if;	
															
																	
										when HDR_INIT		=>	-- error handling - header
															if(	(RX_HDR.EB_MAGIC /= c_EB_MAGIC_WORD) 	-- not EB
															OR 	(RX_HDR.VER /= c_EB_MY_VER)				-- wrong version	
															OR	(RX_HDR.ADDR_SIZE > 3)					-- wrong size
															OR  (RX_HDR.ADDR_PORT > 3))					-- wrong size
															OR  (RX_HDR.STATUS_ADDR = (others => '1'))) -- status addr says "error occurred"
															then
																state_RX <= ERROR;
															else
																--only send an answer if status addr > 0
																if(unigned(RX_HDR.STATUS_ADDR) > 0) then 
																	RX_EB_count		<= 0;		
																	state_TX <= HDR_INIT;
																else
																	state_TX <= EB_DONE;
																end if;	
															end if;
										when CYC_HDR_REC	=>  							
										when WB_READ_INIT	=> 	-- if no cnt value > 0, this was just to probe us and is the last cycle
															if(state_TX = DATA_SEND) then
																state_RX = DATA_SEND
															else
																RX_cyc_rd_count <= RX_CURRENT_CYC.RD_CNT-1; -- eg 1 - 1 = 0, undeflow at -1 => 1 execution
																if(RX_CURRENT_CYC.RD_CNT > 0) then
																	--init cycle header
																	master_IC_o.CYC <= '1';
																	state_TX <= INIT_CYC_HDR;
																	
																	--setup word counters
																	if(RX_CURRENT_CYC.RD_FIFO = '1')) then
																		WB_M_ADDR_MUX <= CONST;
																	else
																		
																	end if;
																	
																else
																	state_RX <=  WB_WRITE_INIT;	
																end if;	
															end if;
										
										when WB_READ	=>	--inc status cnt
															if(RX_cyc_rd_done = '0') then --underflow of RX_cyc_rd_count 	
																master_IC_o.ADR 		<= slave_RX_stream_i.DAT;
																master_IC_o.STB 		<= slave_RX_stream_i.STB;
																slave_RX_stream_o.ACK 	<= master_IC_i.ACK;
																
																if(master_IC_i.ACK = '1') then
																	RX_cyc_rd_count 	<= RX_cyc_rd_count-1;
																	eb_word_count 	<= eb_word_count+1;
																end if;	
															else		
																state_TX <=  CYC_DONE;
																state_RX <=  WB_WRITE_INIT;
															end if;	
										
										when WB_WRITE_INIT	=> 	if(RX_CURRENT_CYC.WR_CNT > 0) then
																	--setup word counters
																	if(RX_CURRENT_CYC.WR_FIFO = '1')) then
																		WB_M_ADDR_MUX <= CONST;
																	else
																		WB_M_ADDR_MUX <= LIST; 
																	end if;
																	
																else
																	-- no writes to do, proceed to either next cycle or finish
																	if(--word 
																end if;
															end if;
										when WB_WRITE	=> 	
										
										when EB_DONE 	=>  master_IC_o.CYC <= '0';
															state_RX <= IDLE;
										
										when ERROR		=> if( (RX_HDR.VER 			/= c_EB_MY_VER)				-- wrong version	
															OR (RX_HDR.ADDR_SIZE 	/= c_EB_MY_ADDR_WIDTH)					-- wrong size
															OR (RX_HDR.PORT_SIZE 	/= c_EB_MY_PORT_WIDTH))	then
																state_TX <= INIT_ERROR_HDR; 
															end if;			
															state_RX <= EB_DONE;
											
										
										when others 	=> state_main <= IDLE;
									end case;
									
									
									master_TX_stream_o.STB <= '0';		
									
									case state_TX is
										when IDLE 			=> 
										
										when HDR_INIT		=>	TX_HDR				<= INIT_EB_HDR;
																
										
										when HDR_PROBE_INIT	=>	TX_HDR				<= INIT_EB_HDR;
																-- change all width to minimum req 
																	
										when HDR_SEND		=>	master_TX_stream_o.CYC <= '1';
																master_TX_stream_o.STB <= '1';
																master_TX_stream_o.DAT <= TO_STD_LOGIC_VECTOR(TX_HDR);		
																
										when CYC_HDR_INIT	=>	TX_CURRENT_CYC.RD_FIFO	<= '0';
																TX_CURRENT_CYC.RD_CNT	<= (others => '0');
																TX_CURRENT_CYC.WR_FIFO 	<= RX_CURRENT_CYC.RD_FIFO;
																TX_CURRENT_CYC.WR_CNT 	<= RX_CURRENT_CYC.RD_CNT;
																
										when CYC_HDR_SEND	=>	--
																master_TX_stream_o.STB <= '1';
																master_TX_stream_o.DAT <= TO_STD_LOGIC_VECTOR(TX_CURRENT_CYC);
																state_TX <= DATA_SEND;			
										
										when DATA_SEND		=>	--only write at the moment!
																master_TX_stream_o.STB <= master_IC_i.ACK;	
																master_TX_stream_o.DAT <= master_IC_i.DAT;	
										
										when CYC_DONE		=>	
										
																	
										when EB_DONE		=>	master_TX_stream_o.CYC <= '0';
										
										when others 	=> state_main <= IDLE;
									end case;
									
				when others		=>	state_main <= IDLE;							
			
					
					
			
			
		end if;
	end if;    
	
end process;

end behavioral;