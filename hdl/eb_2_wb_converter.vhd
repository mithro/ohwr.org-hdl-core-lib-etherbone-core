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
															
																	
										when HDR_SETUP		=>	-- error handling - header
															if(	(RX_HDR.EB_MAGIC /= c_EB_MAGIC_WORD) 	-- not EB
															OR 	(RX_HDR.VER /= c_EB_MY_VER)				-- wrong version	
															OR	(RX_HDR.ADDR_SIZE > 3)					-- wrong size
															OR  (RX_HDR.ADDR_PORT > 3))					-- wrong size
															--OR  (RX_HDR.STATUS_ADDR = (others => '1'))) -- status addr says "error occurred"
															then
																state_RX <= ERROR;
															else
																--only send an answer if status addr > 0
																if(unigned(RX_HDR.STATUS_ADDR) > 0) then 
																	TX_HDR		<= INIT_EB_HDR;
																	
																		
																	state_TX <= HDR_SEND;
																else
																	state_TX <= EB_DONE;
																end if;	
															end if;
										when CYC_REC	=>  							
										when CYC_SETUP  => 	-- if no cnt value > 0, this was just to probe us and is the last cycle
															state_RX <= EB_DONE;
															
															if(RX_CURRENT_CYC.RD_CNT > 0) then
																--init cycle header
																TX_CURRENT_CYC.RD_FIFO	<= '0';
																TX_CURRENT_CYC.RD_CNT	<= (others => '0');
																TX_CURRENT_CYC.WR_FIFO 	<= RX_CURRENT_CYC.RD_FIFO;
																TX_CURRENT_CYC.WR_CNT 	<= RX_CURRENT_CYC.RD_CNT;
																
																--setup word counters
																if(RX_CURRENT_CYC.RD_FIFO = '1')) then
																else
																end if;
																state_TX <= CYC_SEND;
															end if;
															
															--process write request
															if(RX_CURRENT_CYC.WR_CNT > 0) then
																if(RX_CURRENT_CYC.WR_FIFO = '1') then
																else
																end if;	
																
															end if;	

															if(		
	
															
															
										when WB_READ	=>	--wenn wb cycle mit read, send TX_cycle headermaster_TX_stream_o
										when WB_WRITE	=>
										
															DATA_SEND;
										when ERROR		=> EB_TX.;	
										when others 	=> state_main <= IDLE;
									end case;
									
									case state_TX is
										when IDLE 			=> 
										when HDR_SEND		=>
										when HDR_DONE		=>
										when CYC_SEND		=>
										when DATA_SEND		=>
										when CYC_DONE		=>
										when STATUS_SEND 	=>
										when EB_DONE		=>
										
										when others 	=> state_main <= IDLE;
									end case;
									
				when others		=>	state_main <= IDLE;							
			
					
					
			
			
		end if;
	end if;    
	
end process;

end behavioral;