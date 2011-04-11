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

entity EB_RX_CTRL is 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		--Eth MAC WB Streaming signals
		wb_master_i			: in	wishbone_master_in;
		wb_master_o			: out	wishbone_master_out;

		RX_slave_slv_o     : out   std_logic_vector(35 downto 0);	--! Wishbone master output lines
		RX_slave_slv_i     : in     std_logic_vector(70 downto 0);    --! 
		--RX_master_o     : out   wishbone_master_out;	--! Wishbone master output lines
		--RX_master_i     : in    wishbone_master_in    --!
		

		
		reply_MAC_o			: out  std_logic_vector(47 downto 0);
		reply_IP_o			: out  std_logic_vector(31 downto 0);
		reply_PORT_o		: out  std_logic_vector(15 downto 0);

		TOL_o				: out std_logic_vector(15 downto 0);
		
		valid_o				: out std_logic
		
);
end entity;


architecture behavioral of EB_RX_CTRL is


type st is (IDLE, HDR_RECEIVE, CALC_CHKSUM, WAIT_STATE, CHECK_HDR, PAYLOAD_RECEIVE, ERROR);

signal state_RX 	: st := IDLE;

type stmux is (HEADER, PAYLOAD);

signal state_mux	: stmux := HEADER;


signal ETH_RX 		: ETH_HDR;
signal IPV4_RX 		: IPV4_HDR;
signal UDP_RX 		: UDP_HDR;

signal RX_HDR_slv 	: std_logic_vector(192 + 160 + 64-1 downto 0);
alias  ETH_RX_slv 	: std_logic_vector(192-1 downto 0) 	is RX_HDR_slv(192 + 160 + 64-1 downto 160 + 64);
alias  IPV4_RX_slv 	: std_logic_vector(160-1 downto 0) 	is RX_HDR_slv(160 + 64-1 downto 64);
alias  UDP_RX_slv 	: std_logic_vector(64-1 downto 0) 	is RX_HDR_slv(64-1 downto 0);


signal sh_RX_en 	: std_logic;


signal counter_input		: unsigned(7 downto 0);
signal counter_chksum		: unsigned(7 downto 0);




signal  RX_slave_o : wishbone_slave_out;	--! Wishbone master output lines
signal  RX_slave_i : wishbone_slave_in;

signal  RX_hdr_o 				: wishbone_slave_out;	--! Wishbone master output lines
signal  wb_payload_stb_o 	: wishbone_master_out;

--signal 	p_chk_vals		: std_logic_vector(95 downto 0);
--signal  s_chk_vals		: std_logic_vector(15 downto 0);
	
--signal 	IP_chk_sum		: std_logic_vector(15 downto 0);

signal  sh_chk_en 		: std_logic;         
signal  calc_chk_en	: std_logic;
signal  ld_p_chk_vals		: std_logic;            --parallel load



component sipo_sreg_gen 
  generic(g_width_in : natural := 32; g_width_out : natural := 416);
   port(
  		d_i		: in	std_logic_vector(g_width_in -1 downto 0);
  		q_o		: out	std_logic_vector(g_width_out -1 downto 0);
  		clk_i	: in	std_logic;
  		nRST_i	: in 	std_logic;
  		en_i	: in 	std_logic;
  		clr_i	: in 	std_logic
  	);
  end component;

--  signal en_i: std_logic;
signal clr_sreg: std_logic ;








 -- signal chksum_done: std_logic;




begin

ETH_RX	<= TO_ETH_HDR(ETH_RX_slv);
IPV4_RX	<= TO_IPV4_HDR(IPV4_RX_slv);
UDP_RX	<= TO_UDP_HDR(UDP_RX_slv);

-- necessary to make QUARTUS SOPC build_RX_hdrer see the WB intreface as conduit
RX_slave_slv_o <=	TO_STD_LOGIC_VECTOR(RX_slave_o);
RX_slave_i		<=	TO_wishbone_slave_in(RX_slave_slv_i);

  -- Insert values for generic parameters !!
Shift_in: sipo_sreg_gen generic map (32, 416)
                        port map ( d_i         => RX_slave_i.DAT,
                                   q_o         => RX_HDR_slv,
                                   clk_i       => clk_i,
                                   nRST_i      => nRST_i,
                                   en_i        => sh_RX_en,
                                   clr_i       => clr_sreg );

	


sh :	sh_RX_en  <= 	 '1' when ((state_rx = IDLE OR state_rx = HDR_RECEIVE )AND RX_slave_i.CYC = '1' AND RX_slave_i.STB = '1')
			else '0';

--RX_hdr_o.DAT 	<=	s_out;

MUX_RX : with state_mux select 
RX_slave_o	<=  RX_hdr_o 						when HEADER,
				wishbone_slave_out(wb_master_i)	when PAYLOAD,
				RX_hdr_o 						when others;

MUX_WB : with state_mux select
wb_master_o <=	wb_payload_stb_o when HEADER,
				wishbone_master_out(RX_slave_i) when PAYLOAD,
				wishbone_master_out(RX_slave_i) when others;

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
			RX_hdr_o.STALL 			<= '0';
			RX_hdr_o.ERR 			<= '0';
			RX_hdr_o.DAT 			<= (others => '0');
			RX_hdr_o.RTY  			<= '0';
			
			wb_payload_stb_o.STB 	<= '0';
			wb_payload_stb_o.CYC 	<= '0';
			wb_payload_stb_o.WE 	<= '1';
			wb_payload_stb_o.SEL 	<= (others => '1');
			wb_payload_stb_o.ADR 	<= (others => '0');
			wb_payload_stb_o.DAT 	<= (others => '0');
	
			
			state_mux	<= HEADER;
			

			counter_input 	<= (others => '0');
			counter_chksum	<=	(others => '0');
			 -- prepare chk sum field_RX_hdr, fill in reply IP and TOL field_RX_hdr when available
			ld_p_chk_vals		<= '0';
			sh_chk_en		<= '0';
			calc_chk_en <= '0';
			clr_sreg	<= '0';
			
			valid_o <= '0';
		else
			
			clr_sreg <= '0';
			--sh_RX_en <= '1';
			

			
			ld_p_chk_vals		<= '0';
			sh_chk_en		<= '0';
			calc_chk_en		<= '0';
			
			valid_o <= '0';
			RX_hdr_o.STALL 			<= '0';
			
			if((RX_slave_i.CYC = '0') AND NOT ((state_RX = PAYLOAD_RECEIVE) OR (state_RX = IDLE))) then --packet aborted before completion
				state_RX <= ERROR;
			else
			
				case state_RX is
					when IDLE 			=>  RX_hdr_o.STALL 			<= '0';
											state_mux		<= HEADER;
											counter_chksum 	<= (others => '0');
											counter_input 	<= (others => '0');
											--	
											if(RX_slave_i.CYC = '1' AND RX_slave_i.STB = '1') then
												--clr_sreg 		<= '0';
												counter_input 	<= counter_chksum +1;
												state_RX 		<= HDR_RECEIVE;
											end if;	
												
					
					when HDR_RECEIVE	=>	if(counter_input < 12) then	
												counter_input <= counter_input +1;
												--sh_RX_en <= '1';
											else
												RX_hdr_o.STALL 	<= '1';
												state_RX 		<= CHECK_HDR;
											end if;
											
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
					
					when CHECK_HDR		=>	RX_hdr_o.STALL 			<= '1';
										if(ETH_RX.PRE_SFD = c_PREAMBLE) then			
											--if(IP_chksum = x"FFFF") then -- correct ?
													if(IPV4_RX.DST = c_MY_IP OR IPV4_RX.DST = c_BROADCAST_IP) then
														if(IPV4_RX.PRO = c_PRO_UDP) then
															if(UDP_RX.DST_PORT = c_EB_PORT) then
																--copy info to TX for reply
																valid_o <= '1';	
																--
																state_mux	<= PAYLOAD;
																state_rx	<= PAYLOAD_RECEIVE;
																--set payload counter to UDP payload bytes => TOL - 20 - 8
																
															else
																report("Wrong Port") severity warning;
																state_rx	<= ERROR;
															end if;
														else
															report("Not UDP") severity warning;
															state_rx	<= ERROR;
														end if;	
													else
														report("Wrong Dst IP") severity warning;
														state_rx	<= ERROR;
													end if;		
												--else
												--	report("Bad IP checksum") severity warning;
												--	state_rx	<= ERROR;
												--end if;
											else
												report("No Eth Preamble found") severity warning;
												state_rx	<= ERROR;
											end if;
		

					when PAYLOAD_RECEIVE	=>  if(RX_slave_i.CYC = '0') then
													state_RX <= IDLE;
												end if;
					
					when ERROR				=>  clr_sreg 		<= '1';
												state_rx	<= IDLE;
					
					when others =>			state_RX <= IDLE;			
				
				
				end case;
			
			end if;
					
			
			
		end if;
	end if;    
	
end process;



end behavioral;