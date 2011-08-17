---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;
--use work.EB_components_pkg.all;
use work.wb32_package.all;
use work.wb16_package.all;

entity EB_RX_CTRL is 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		
		RX_slave_o     : out   wb16_slave_out;	--! Wishbone master output lines
		RX_slave_i     : in    wb16_slave_in;    --!
		
		--Eth MAC WB Streaming signals
		wb_master_i			: in	wb32_master_in;
		wb_master_o			: out	wb32_master_out;

		reply_VLAN_o		: out	std_logic_vector(31 downto 0);
		reply_MAC_o			: out  std_logic_vector(47 downto 0);
		reply_IP_o			: out  std_logic_vector(31 downto 0);
		reply_PORT_o		: out  std_logic_vector(15 downto 0);

		TOL_o				: out std_logic_vector(15 downto 0);
		

		valid_o				: out std_logic
		
);
end entity;


architecture behavioral of EB_RX_CTRL is

component WB_bus_adapter_streaming_sg
  generic(g_adr_width_A : natural := 32; g_adr_width_B  : natural := 32;
  		g_dat_width_A : natural := 32; g_dat_width_B  : natural := 16;
  		g_pipeline : natural 
  		);
  port(
  		clk_i		: in std_logic;
  		nRst_i		: in std_logic;
  		A_CYC_i		: in std_logic;
  		A_STB_i		: in std_logic;
  		A_ADR_i		: in std_logic_vector(g_adr_width_A-1 downto 0);
  		A_SEL_i		: in std_logic_vector(g_dat_width_A/8-1 downto 0);
  		A_WE_i		: in std_logic;
  		A_DAT_i		: in std_logic_vector(g_dat_width_A-1 downto 0);
  		A_ACK_o		: out std_logic;
  		A_ERR_o		: out std_logic;
  		A_RTY_o		: out std_logic;
  		A_STALL_o	: out std_logic;
  		A_DAT_o		: out std_logic_vector(g_dat_width_A-1 downto 0);
  		B_CYC_o		: out std_logic;
  		B_STB_o		: out std_logic;
  		B_ADR_o		: out std_logic_vector(g_adr_width_B-1 downto 0);
  		B_SEL_o		: out std_logic_vector(g_dat_width_B/8-1 downto 0);
  		B_WE_o		: out std_logic;
  		B_DAT_o		: out std_logic_vector(g_dat_width_B-1 downto 0);
  		B_ACK_i		: in std_logic;
  		B_ERR_i		: in std_logic;
  		B_RTY_i		: in std_logic;
  		B_STALL_i	: in std_logic;
  		B_DAT_i		: in std_logic_vector(g_dat_width_B-1 downto 0)
  );
  end component;

component sipo_flag is
generic(g_width_IN : natural := 16; g_width_OUT  : natural := 32); 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		d_i					: in std_logic_vector(g_width_IN-1 downto 0);
		en_i				: in std_logic;
		clr_i				: in std_logic;
		
		q_o					: out std_logic_vector(g_width_OUT-1 downto 0);
		full_o				: out std_logic;
		empty_o				: out std_logic
);
end component;

signal conv_A    : wb16_slave_out;	--! Wishbone master output lines
signal conv_B    : wb32_master_out;    --!
		

-- main FSM
type st is (IDLE, HDR_RECEIVE, CALC_CHKSUM, WAIT_STATE, CHECK_HDR, PAYLOAD_RECEIVE, ERROR);
signal state_RX 	: st := IDLE;

--split shift register output and convert to hdr records
signal ETH_RX 		: ETH_HDR;
signal IPV4_RX 		: IPV4_HDR;
signal UDP_RX 		: UDP_HDR;
signal RX_HDR_slv 	: std_logic_vector(c_ETH_HLEN + c_IPV4_HLEN + c_UDP_HLEN-1 downto 0);
alias  ETH_RX_slv 	: std_logic_vector(c_ETH_HLEN -1 downto 0) 	is RX_HDR_slv(c_ETH_HLEN  + c_IPV4_HLEN + c_UDP_HLEN-1 downto c_IPV4_HLEN + c_UDP_HLEN);
alias  IPV4_RX_slv 	: std_logic_vector(c_IPV4_HLEN-1 downto 0) 	is RX_HDR_slv(c_IPV4_HLEN + c_UDP_HLEN-1 downto c_UDP_HLEN);
alias  UDP_RX_slv 	: std_logic_vector(c_UDP_HLEN-1 downto 0) 	is RX_HDR_slv(c_UDP_HLEN-1 downto 0);

--forking the bus
type 	stmux is (HEADER, PAYLOAD);
signal 	state_mux			: stmux := HEADER;
signal  RX_hdr_o 			: wb16_slave_out;	--! Wishbone master output lines
signal  wb_payload_stb_o 	: wb32_master_out;

--shift register input and control signals
signal counter_input	: unsigned(7 downto 0);
signal sipo_clr			: std_logic;
signal sipo_full		: std_logic;	
signal sipo_empty		: std_logic;
signal sipo_en 			: std_logic;

--IP checksum check NOT USED ATM
--signal 	p_chk_vals		: std_logic_vector(95 downto 0);
--signal  s_chk_vals		: std_logic_vector(15 downto 0);
--signal 	IP_chk_sum		: std_logic_vector(15 downto 0);      
signal  calc_chk_en			: std_logic;
signal  ld_p_chk_vals		: std_logic;            --parallel load
signal counter_chksum		: unsigned(7 downto 0);
signal sh_chk_en 			: std_logic; 
--  signal en_i				: std_logic;
-- signal chksum_done		: std_logic;

signal PAYLOAD_STB_i : std_logic;
signal PAYLOAD_CYC_i : std_logic;


begin

ETH_RX	<= TO_ETH_HDR(ETH_RX_slv);
IPV4_RX	<= TO_IPV4_HDR(IPV4_RX_slv);
UDP_RX	<= TO_UDP_HDR(UDP_RX_slv);

Shift_in: sipo_flag generic map (16, c_ETH_HLEN + c_IPV4_HLEN + c_UDP_HLEN)
                        port map ( d_i         => RX_slave_i.DAT,
                                   q_o         => RX_HDR_slv,
                                   clk_i       => clk_i,
                                   nRST_i      => nRST_i,
                                   en_i        => sipo_en,
                                   clr_i       => sipo_clr, 
								   full_o	   => sipo_full,
									empty_o		=> sipo_empty
								   );

sh :	sipo_en  <= 	 '1' when (sipo_full = '0' AND RX_slave_i.CYC = '1' AND RX_slave_i.STB = '1')
			else '0';	


-- convert streaming input from 16 to 32 bit data width
uut: WB_bus_adapter_streaming_sg generic map (   g_adr_width_A => 32,
                                                 g_adr_width_B => 32,
                                                 g_dat_width_A => 16,
                                                 g_dat_width_B => 32,
                                                 g_pipeline    =>  3)
                                      port map ( clk_i         => clk_i,
                                                 nRst_i        => nRst_i,
                                                 A_CYC_i       => PAYLOAD_CYC_i,
                                                 A_STB_i       => PAYLOAD_STB_i,
                                                 A_ADR_i       => RX_slave_i.ADR,
                                                 A_SEL_i       => RX_slave_i.SEL,
                                                 A_WE_i        => RX_slave_i.WE,
                                                 A_DAT_i       => RX_slave_i.DAT,
                                                 A_ACK_o       => conv_A.ACK,
                                                 A_ERR_o       => conv_A.ERR,
                                                 A_RTY_o       => conv_A.RTY,
                                                 A_STALL_o     => conv_A.STALL,
                                                 A_DAT_o       => conv_A.DAT,
                                                 B_CYC_o       => conv_B.CYC,
                                                 B_STB_o       => conv_B.STB,
                                                 B_ADR_o       => conv_B.ADR,
                                                 B_SEL_o       => conv_B.SEL,
                                                 B_WE_o        => conv_B.WE,
                                                 B_DAT_o       => conv_B.DAT,
                                                 B_ACK_i       => wb_master_i.ACK,
                                                 B_ERR_i       => wb_master_i.ERR,
                                                 B_RTY_i       => wb_master_i.RTY,
                                                 B_STALL_i     => wb_master_i.STALL,
                                                 B_DAT_i       => wb_master_i.DAT); 



RX_hdr_o.STALL <= 	sipo_full;  								   
								   
MUX_RX : with state_mux select 
RX_slave_o	<=  conv_A	when PAYLOAD,
				RX_hdr_o 						when others;
				
MUX_PAYLOADSTB : with state_mux select 
PAYLOAD_STB_i	<=  RX_slave_i.STB	when PAYLOAD,
				'0' 						when others;

MUX_PAYLOADCYC : with state_mux select 
PAYLOAD_CYC_i	<=  RX_slave_i.CYC	when PAYLOAD,
				'0' 						when others;				


MUX_WB : with state_mux select
wb_master_o <=	conv_B when PAYLOAD,
				wb_payload_stb_o when others;
				
				

--postpone VLAN support
--reply_VLAN_o	<= ETH_RX.TPID & ETH_RX.PCP & ETH_RX.CFI & ETH_RX.VID;				
reply_MAC_o		<= ETH_RX.SRC;
reply_IP_o		<= IPV4_RX.SRC;
reply_PORT_o	<= UDP_RX.SRC_PORT;
TOL_o			<= IPV4_RX.TOL;
				
main_fsm : process(clk_i)
begin
	if rising_edge(clk_i) then

	   --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0') then
			
			RX_hdr_o.ACK 			<= '0';
			
			RX_hdr_o.ERR 			<= '0';
			RX_hdr_o.DAT 			<= (others => '0');
			RX_hdr_o.RTY  			<= '0';
			
			wb_payload_stb_o.STB 	<= '0';
			wb_payload_stb_o.CYC 	<= '1';
			wb_payload_stb_o.WE 	<= '1';
			wb_payload_stb_o.SEL 	<= (others => '1');
			wb_payload_stb_o.ADR 	<= (others => '0');
			wb_payload_stb_o.DAT 	<= (others => '0');
	
			
			state_mux	<= HEADER;
			

			counter_input 			<= (others => '0');
			counter_chksum			<=	(others => '0');
			 -- prepare chk sum field_RX_hdr, fill in reply IP and TOL field_RX_hdr when available
			ld_p_chk_vals			<= '0';
			sh_chk_en				<= '0';
			calc_chk_en 			<= '0';
		else
			
			sipo_clr 				<= '0';
			valid_o 				<= '0';
			
			ld_p_chk_vals			<= '0';
			sh_chk_en				<= '0';
			calc_chk_en				<= '0';
			


			
			if((RX_slave_i.CYC = '0') AND NOT ((state_RX = PAYLOAD_RECEIVE) OR (state_RX = IDLE))) then --packet aborted before completion
				state_RX 	<= ERROR;
			else
			
				case state_RX is
					when IDLE 			=>  state_mux		<= HEADER;
											counter_chksum 	<= (others => '0');
											counter_input 	<= (others => '0');
											--sipo_clr 		<= '1';
											if(RX_slave_i.CYC = '1' AND RX_slave_i.STB = '1') then

												counter_input 	<= counter_chksum +1;
												state_RX 		<= HDR_RECEIVE;
											end if;	
												
					when HDR_RECEIVE	=>	if(sipo_full = '1') then -- VLAN?
												state_RX 		<= CHECK_HDR;	
											end if;
											
												
												--if(RX_slave_i.DAT = x"8100") then
												
											
											
											--counter_input <= counter_input + 1;
												
																						
					-- when CALC_CHKSUM	=>	RX_hdr_o.STALL 			<= '1';
											-- if(counter_chksum < 6) then
												-- sh_chk_en <= '1';
												-- calc_chk_en <= '1';
												-- counter_chksum 	<= counter_chksum +1;
											-- else
												-- if(chksum_done = '1') then
													-- state_RX 		<= WAIT_STATE;
												-- end if;	
											-- end if;	
					
					when WAIT_STATE		=> 	state_RX 		<= CHECK_HDR;
					
					when CHECK_HDR		=>	--RX_hdr_o.STALL 			<= '1';
										--if(ETH_RX.PRE_SFD = c_PREAMBLE) then			
											--if(IP_chksum = x"FFFF") then -- correct ?
													--if(IPV4_RX.DST = c_MY_IP OR IPV4_RX.DST = c_BROADCAST_IP) then
														--if(IPV4_RX.PRO = c_PRO_UDP) then
															--if(UDP_RX.DST_PORT = c_EB_PORT) then
																--copy info to TX for reply
																if(ETH_RX.TYP = x"0800" AND IPV4_RX.PRO = x"11") then
																	valid_o <= '1';	
																	--
																	state_mux	<= PAYLOAD;
																	state_rx	<= PAYLOAD_RECEIVE;
																else
																	report("BAD PACKET HDR") severity Warning; 
																	state_rx	<= ERROR;
																end if;	
																--set payload counter to UDP payload bytes => TOL - 20 - 8
																
															--else
															--	report("Wrong Port") severity warning;
															--	state_rx	<= ERROR;
															--end if;
														--else
														--	report("Not UDP") severity warning;
														--	state_rx	<= ERROR;
														--end if;	
													--else
														--report("Wrong Dst IP") severity warning;
														--state_rx	<= ERROR;
													--end if;		
												--else
												--	report("Bad IP checksum") severity warning;
												--	state_rx	<= ERROR;
												--end if;
											--else
											--	report("No Eth Preamble found") severity warning;
											--	state_rx	<= ERROR;
											--end if;
		

					when PAYLOAD_RECEIVE	=>  if(RX_slave_i.CYC = '0') then
													state_RX <= IDLE;
													sipo_clr 		<= '1';
												end if;
					
					when ERROR				=>  sipo_clr 		<= '1';
												state_rx	<= IDLE;
					
					when others =>			state_RX <= IDLE;			
				
				
				end case;
			
			end if;
					
			
			
		end if;
	end if;    
	
end process;



end behavioral;