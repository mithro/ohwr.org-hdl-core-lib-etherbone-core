--! @file EB_RX_CTRL.vhd
--! @brief EtherBone RX Packet/Frame parser
--!
--! Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--! @bug No know bugs.
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

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
use work.wr_fabric_pkg.all;

entity EB_RX_CTRL is
  
  port (
    clk_i   : in std_logic;
    nRst_i : in std_logic;

    -- Wishbone Fabric Interface I/O
    snk_i : in  t_wrf_sink_in;
    snk_o : out t_wrf_sink_out;

    --Eth MAC WB Streaming signals
    wb_master_i : in  wb32_master_in;
    wb_master_o : out wb32_master_out;

    reply_MAC_o  : out std_logic_vector(6*8-1 downto 0);
    reply_IP_o   : out std_logic_vector(4*8-1 downto 0);
    reply_Port_o : out std_logic_vector(2*8-1 downto 0);
    TOL_o        : out std_logic_vector(2*8-1 downto 0);
    payload_len_o : out std_logic_vector(2*8-1 downto 0);
    
    my_mac_i  : in std_logic_vector(6*8-1 downto 0);
    my_vlan_i : in std_logic_vector(2*8-1 downto 0); 
    my_ip_i   : in std_logic_vector(4*8-1 downto 0);
    my_port_i : in std_logic_vector(2*8-1 downto 0);
    
    valid_o : out std_logic

    );
end entity;


architecture behavioral of EB_RX_CTRL is

  component WB_bus_adapter_streaming_sg
    generic(g_adr_width_A : natural := 32; g_adr_width_B : natural := 32;
    g_dat_width_A         : natural := 32; g_dat_width_B : natural := 16;
    g_pipeline            : natural
            );
    port(
      clk_i     : in  std_logic;
      nRst_i    : in  std_logic;
      A_CYC_i   : in  std_logic;
      A_STB_i   : in  std_logic;
      A_ADR_i   : in  std_logic_vector(g_adr_width_A-1 downto 0);
      A_SEL_i   : in  std_logic_vector(g_dat_width_A/8-1 downto 0);
      A_WE_i    : in  std_logic;
      A_DAT_i   : in  std_logic_vector(g_dat_width_A-1 downto 0);
      A_ACK_o   : out std_logic;
      A_ERR_o   : out std_logic;
      A_RTY_o   : out std_logic;
      A_STALL_o : out std_logic;
      A_DAT_o   : out std_logic_vector(g_dat_width_A-1 downto 0);
      B_CYC_o   : out std_logic;
      B_STB_o   : out std_logic;
      B_ADR_o   : out std_logic_vector(g_adr_width_B-1 downto 0);
      B_SEL_o   : out std_logic_vector(g_dat_width_B/8-1 downto 0);
      B_WE_o    : out std_logic;
      B_DAT_o   : out std_logic_vector(g_dat_width_B-1 downto 0);
      B_ACK_i   : in  std_logic;
      B_ERR_i   : in  std_logic;
      B_RTY_i   : in  std_logic;
      B_STALL_i : in  std_logic;
      B_DAT_i   : in  std_logic_vector(g_dat_width_B-1 downto 0)
      );
  end component;

  component sipo_flag is
    generic(g_width_IN : natural := 16; g_width_OUT : natural := 32);
    port(
      clk_i  : in std_logic;
      nRst_i : in std_logic;

      d_i   : in std_logic_vector(g_width_IN-1 downto 0);
      en_i  : in std_logic;
      clr_i : in std_logic;

      q_o     : out std_logic_vector(g_width_OUT-1 downto 0);
      full_o  : out std_logic;
      empty_o : out std_logic
      );
  end component;




  signal snk_buffer : std_logic_vector(15 downto 0);
  signal snk_payload_conv : t_wrf_sink_out;
    signal snk_hdr_fsm : t_wrf_sink_out;
         --! Wishbone master output lines
 signal conv_B : wb32_master_out;      --!
  signal payload_cyc : std_logic;
  signal snk_hdr_fsm_ACK : std_logic;

  signal parser_reset : std_logic;
  signal parser_wait : std_logic;
signal snk_WR : std_logic;
signal get_last_element	: std_logic;

signal snk_hdr_fsm_stall : std_logic;
  signal snk_buffer_empty : std_logic;
  	

-- main FSM
  type   st is (IDLE, HEADER, PAYLOAD, PADDING, DONE, ERRORS);
  signal state : st := IDLE;
  type   st_parse is (IDLE, ETH, ETH_CAPTURE, ETH_CHK, IPV4,  IPV4_CAPTURE, IPV4_CHKSUM, IPV4_OPT, UDP, UDP_FETCH_BUF, UDP_CAPTURE, CHK, DONE, ERRORS, waits);
  signal parse : st_parse := ETH;

--split shift register output and convert to hdr records
  signal ETH_RX  : ETH_HDR;
  --signal ETH_Q_RX  : ETH_Q_HDR;
  signal IPV4_RX : IPV4_HDR;
  signal UDP_RX  : UDP_HDR;
  signal payload_len : std_logic_vector(2*8-1 downto 0);

signal RX_HDR_slv : std_logic_vector(c_IPV4_HLEN*8-1 downto 0) 		;





--shift register input and control signals
  signal byte_count : natural range 0 to 1600;
  signal counter_comp : natural range 0 to 1600;
  signal eop : natural range 0 to 1600;	

  

    signal hdr_done      : std_logic;

  signal sipo_clr      : std_logic;
  signal sipo_full     : std_logic;
  signal sipo_empty    : std_logic;
  signal sipo_en       : std_logic;

		

begin


-------------------------------------------------------------------------------
--                           Payload converter                               --
-------------------------------------------------------------------------------

-- convert streaming input from 16 to 32 bit data width
  uut : WB_bus_adapter_streaming_sg generic map (g_adr_width_A => 2,
                                                 g_adr_width_B => 32,
                                                 g_dat_width_A => 16,
                                                 g_dat_width_B => 32,
                                                 g_pipeline    => 3)
    port map (clk_i     => clk_i,
              nRst_i    => nRst_i,
              A_CYC_i   => payload_cyc,
              A_STB_i   => snk_i.stb,
              A_ADR_i   => snk_i.adr,
              A_SEL_i   => snk_i.sel,
              A_WE_i    => snk_i.we,
              A_DAT_i   => snk_i.dat,
              A_ACK_o   => snk_payload_conv.ack,
              A_ERR_o   => snk_payload_conv.err,
              A_RTY_o   => snk_payload_conv.rty,
              A_STALL_o => snk_payload_conv.stall,
              A_DAT_o   => open,
              B_CYC_o   => conv_B.CYC,
              B_STB_o   => conv_B.STB,
              B_ADR_o   => conv_B.ADR,
              B_SEL_o   => conv_B.SEL,
              B_WE_o    => conv_B.WE,
              B_DAT_o   => conv_B.DAT,
              B_ACK_i   => wb_master_i.ACK,
              B_ERR_i   => wb_master_i.ERR,
              B_RTY_i   => wb_master_i.RTY,
              B_STALL_i => wb_master_i.STALL,
              B_DAT_i   => wb_master_i.DAT); 


 -- Mux hdr fsm / payload converter
MUX_SNK_O : with state select
	snk_o <= 	snk_payload_conv	when PAYLOAD,
			snk_hdr_fsm     	when others;

MUX_SNK_I : with state select
	payload_cyc <= 	snk_i.cyc 		when PAYLOAD,
			'0' 			when others;

wb_master_o <= conv_B;

-------------------------------------------------------------------------------
--                           Header FSM                                      --
-------------------------------------------------------------------------------

-- hdr fsm outputs  
snk_hdr_fsm.err 	<= '0'; 		--? does wr-core handle the error line ?
snk_hdr_fsm.ack 	<= snk_hdr_fsm_ACK;	
snk_hdr_fsm.stall 	<= parser_wait or snk_hdr_fsm_stall; -- enable drivers in two different processes  

-- outputs to TX block                     

reply_MAC_o 	<= ETH_RX.SRC;
reply_IP_o   	<= IPV4_RX.SRC;
reply_PORT_o 	<= UDP_RX.SRC_PORT;
payload_len 	<= UDP_RX.MLEN;
payload_len_o 	<= payload_len;


TOL_o        	<= IPV4_RX.TOL;

  Shift_in : sipo_flag generic map (16, c_IPV4_HLEN*8) --IP header is longest possibility
    port map (d_i     => snk_buffer,
              q_o     => RX_HDR_slv,
              clk_i   => clk_i,
              nRST_i  => nRST_i,
              en_i    => sipo_en,
              clr_i   => sipo_clr,
              full_o  => sipo_full,
              empty_o => sipo_empty);



sipo_en <= (not snk_buffer_empty) or get_last_element;


feed_buffer : process(clk_i)
begin
	if rising_edge(clk_i) then
		if (nRST_i = '0' or parser_reset = '1') then		
		snk_buffer_empty <= '1';
		sipo_clr <= '0';
		byte_count <= 0;
		else		
			snk_hdr_fsm_ACK <= '0';
			snk_buffer_empty <= '1';
			if(snk_i.adr = c_WRF_DATA) then -- everything else is OOB and must be ignored
				if(snk_i.stb = '1' and snk_i.cyc = '1' and ((snk_payload_conv.stall = '0' and state = PAYLOAD) or (snk_hdr_fsm.stall = '0' and state /= PAYLOAD))) then
						snk_buffer_empty <= '0';
						snk_buffer 		<= snk_i.dat;	
						snk_hdr_fsm_ACK 	<= '1';
						byte_count <= byte_count + 2;	
			

				end if;
			end if;
		end if;		 
		
	end if;
end process;



snk_WR <= NOT snk_hdr_fsm.stall AND snk_i.cyc AND snk_i.stb;


	
	



parser : process(clk_i)
begin
	if rising_edge(clk_i) then
		if (nRST_i = '0') then
	  	 parser_wait <= '0';
		 get_last_element <= '0';
		 parse <= idle;
		valid_o <= '0';		
		else			
			parser_wait <= '0';			
			get_last_element <= '0';
				case parse is
										
					when idle 	=> 	counter_comp <= c_ETH_end;
								if(state = HEADER) then -- data present ? -> start parsing, cycle to fill buffer							
									parse <= ETH;		
								end if;									 	 
					
					when ETH 	=>	if(byte_count = counter_comp AND snk_WR = '1') then	--Eth header minimum length -2
									--report("matched Eth len") severity note;                						
									
										parser_wait <= '1';
										parse <= ETH_CAPTURE;
									
								end if;
					
					when ETH_CAPTURE => 	parser_wait <= '1';
								if(snk_buffer_empty = '0') then								
								ETH_RX  <= TO_ETH_HDR(RX_HDR_slv(c_ETH_HLEN*8-1 downto 0)); --get header
								parse <= ETH_CHK;
								counter_comp <= c_ETH_Q_end;
								end if;						
								
					when ETH_CHK 	=>	if(ETH_RX.TYP = c_ETH_TYPE_IP) then -- proper IP packet type ?
									if(ETH_RX.DST = my_mac_i  or ETH_RX.DST = c_BROADCAST_MAC) then -- addressed to me ?
										parse <= IPV4;
										counter_comp <= c_ETH_end;
									else
										report("RX: not addressed to my MAC") severity warning;
										--parse <= errors;
										counter_comp <= c_ETH_end; 												
										parse <= IPV4;
									end if;			
								else
									--could be a vlan tag. Treat as Eth q frame									
									if(byte_count > counter_comp) then
									parser_wait <= '1';
										if(snk_buffer_empty = '1') then
											--ETH_Q_RX <= TO_ETH_Q_HDR(RX_HDR_slv(c_ETH_Q_HLEN*8-1 downto 0));
											--parse <= ETH_Q;
										end if;
									end if;	
								end if;	
						
							

					--when ETH_Q 	=>	if(ETH_RX.TYP = c_ETH_TYPE_IP) then -- proper IP packet type ?
					--				if(ETH_RX.DST = my_mac_i or ETH_RX.DST = c_BROADCAST_MAC) then -- addressed to me ?
					--					if(ETH_Q_RX.VLAN = my_vlan_i) then -- in my vlan ?
					--						parse <= IPV4;
					--						counter_comp <= c_ETH_Q_end;
					--					else
					--						report("RX: outside my vlan") severity warning;
					--						parse <= errors;
					--					end if;
					--				else
					--					report("RX: not addressed to my MAC") severity warning;
					--					parse <= errors;
					--				end if;			
					--			else
					--				report("RX: wrong packet type") severity warning; 						--				parse <= errors;
					--			end if;

					
						
					when IPV4	 =>	if(byte_count = counter_comp  + c_IPV4_HLEN  AND snk_WR = '1') then
									--report("RX: matched IP len") severity note;
									parser_wait <= '1';
									parse <= IPV4_CAPTURE;
									
								end if;			
					
					when IPV4_CAPTURE => 	if(snk_buffer_empty = '0') then	
								parser_wait <= '1';									
								IPV4_RX    <= TO_IPV4_HDR(RX_HDR_slv(c_IPV4_HLEN*8-1 downto 0)); --
								parse <= IPV4_opt;
								end if;
					
					when IPV4_chksum => null;
					
					when IPV4_opt 	=>	if(byte_count >= counter_comp + to_integer(unsigned(IPV4_RX.IHL) * 4)) then
									parse <= UDP;
								end if;
								
									
						
					when UDP 	=>	if((byte_count = counter_comp  + to_integer(unsigned(IPV4_RX.IHL)*4) + c_UDP_HLEN -2) AND snk_WR = '1') then 										
					--report("RX: matched UDP len") severity note;
									parser_wait <= '1';
									parse <= UDP_FETCH_BUF;
								end if;
					
					when  UDP_FETCH_BUF	=> 	parser_wait <= '1';
									--if(snk_buffer_empty = '0') then
									get_last_element <= '1';
									parse <= UDP_CAPTURE;			
									--end if;

					when UDP_CAPTURE	=>	parser_wait <= '1';
									--										
									UDP_RX    <= TO_UDP_HDR(RX_HDR_slv(c_UDP_HLEN*8-1 downto 0));
									parse <= chk;		
									--
					
					when chk	=>	parser_wait <= '1';
								if(IPV4_RX.DST = my_ip_i or IPV4_RX.DST = c_BROADCAST_IP) then								
									if(UDP_RX.DST_PORT = my_port_i) then								
										report("RX: hdr parsed successfully, handing over payload ...") severity note;
										parse <= done;
										
									else
										report("RX: wrong port") severity warning;
										parse <= errors;
									end if;  				
								else
									report("RX: not addressed to my IP") severity warning;
									--	parse <= errors;
									--parse <= errors;
										parse <= done;
								end if;
					when done	=>	--parser_wait <= '1';
								valid_o <= '1';
								if(parser_reset = '1') then		
									parse <= idle;
								end if;
					
					when errors	=>  	report("RX: error, packet aborted") severity warning;
								           parse <= waits;
	
					when waits	=>   null;   				
					when others     =>	parse <= IDLE;	
				end case;	
			
		end if;
	end if;
end process;

main : process(clk_i)
begin
	if rising_edge(clk_i) then
		if (nRST_i = '0') then
			state <= IDLE;
			
		else
			snk_hdr_fsm_STALL <= '0';
			parser_reset <= '0';
			case state is
										
					when IDLE 	=> 	
								if(snk_i.cyc = '1') then
									--snk_hdr_fsm_STALL <= '0';
									state <= HEADER;								
								end if;	
					
								when HEADER 	=> 	if(parse = DONE) then
									eop <= (counter_comp  + to_integer(unsigned(IPV4_RX.IHL)*4) + to_integer(unsigned(UDP_RX.MLEN)) -2);
									state <= PAYLOAD;
									--snk_hdr_fsm_STALL <= '1';
								else
									if(snk_i.cyc = '0') then
										report("RX: packet hdr aborted") severity warning; 											state <= ERRORS;										
									end if;		
								end if;								 	 
					
		
					when PAYLOAD	=>	if(byte_count <  c_ETH_FRAME_MIN_END) then
									

									if(snk_i.cyc = '0') then
									report("RX:  runt frame (< 64)") severity warning; 										state <= ERRORS;
									elsif(byte_count =  eop) then
										state <= PADDING;
									end if;
								else
									if(snk_i.cyc = '0') then									
										if(byte_count =  eop) then 											state <= DONE; 
										elsif(byte_count >  eop) then
											report("RX: frame too long") severity warning; 												state <= ERRORS;
										else
											report("RX: frame cut short") severity warning; 											state <= ERRORS;
										end if;
																		
									end if;
								
									
								end if;	  					
					
					when PADDING	=>	if(snk_i.cyc = '0') then									
										if(byte_count =  c_ETH_FRAME_MIN_END) then 												state <= DONE; 
										elsif(byte_count > c_ETH_FRAME_MIN_END) then
											report("RX: frame too long") severity warning; 												state <= ERRORS;
										else
											report("RX: frame cut short") severity warning; 											state <= ERRORS;
										end if;
									end if;
					when DONE	=>	parser_reset <= '1'; state <= IDLE;
					when ERRORS     =>	parser_reset <= '1'; state <= IDLE;
 					when others     =>	parser_reset <= '1'; state <= IDLE;
			end case;
		end if;
	end if;
end process;




 



end behavioral;
