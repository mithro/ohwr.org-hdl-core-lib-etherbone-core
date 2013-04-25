--! @file EB_TX_CTRL.vhd
--! @brief EtherBone TX Packet/Frame Builder
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
use work.eb_internals_pkg.all;    
use work.eb_hdr_pkg.all;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;

entity EB_TX_CTRL is
port(
   clk_i				: in std_logic;
   nRst_i			: in std_logic;
		
	--Eth MAC WB Streaming signals
	wb_slave_i		: in	t_wishbone_slave_in;
	wb_slave_o		: out	t_wishbone_slave_out;
   src_i          : in  t_wrf_source_in;
	src_o          : out t_wrf_source_out;

	reply_MAC_i    : in std_logic_vector(6*8-1 downto 0);
	reply_IP_i     : in std_logic_vector(4*8-1 downto 0);
	reply_Port_i   : in std_logic_vector(2*8-1 downto 0);

	TOL_i          : in std_logic_vector(2*8-1 downto 0);
	payload_len_i  : in std_logic_vector(2*8-1 downto 0);

	my_mac_i       : in std_logic_vector(6*8-1 downto 0);
	my_vlan_i      : in std_logic_vector(2*8-1 downto 0); 
	my_ip_i        : in std_logic_vector(4*8-1 downto 0);
	my_port_i      : in std_logic_vector(2*8-1 downto 0);

	silent_i			: in std_logic;
	valid_i			: in std_logic
		
);
end entity;


architecture behavioral of EB_TX_CTRL is


  

signal conv_A    : t_wishbone_slave_out;    --!

-- main FSM
type st is (IDLE, CALC_CHKSUM, WAIT_SEND_REQ, PREP_ETH, ETH, IPV4, UDP, HDR_SEND, PAYLOAD_SEND, PADDING, WAIT_IFGAP, ERRORS);
signal state   : st := IDLE;
signal ETH_TX  : ETH_HDR;
signal IPV4_TX : IPV4_HDR;
signal UDP_TX  : UDP_HDR;

signal TX_HDR_slv       : std_logic_vector(c_IPV4_HLEN*8 -1 downto 0);
--shift register output and control signals
signal byte_count       : natural range 0 to 1600;
signal counter_comp     : natural range 0 to 1600;
signal s_timeout_cnt    : unsigned(14 downto 0);
alias  a_timeout        : unsigned(0 downto 0) is s_timeout_cnt(s_timeout_cnt'left downto s_timeout_cnt'left);  
signal eop              : natural range 0 to 1600;	
signal s_sh_hdr_en      : std_logic;
signal ld_hdr		      : std_logic;
signal chksum_empty 	   : std_logic;

-- forking the bus
type stmux is (HEADER, PAYLOAD, PADDING, NONE);
signal state_mux		   : stmux := HEADER;
signal wb_payload_stall_o 		: t_wishbone_slave_out;
signal stalled  		   : std_logic;

-- IP checksum generator
signal p_chk_vals		   : std_logic_vector(95 downto 0);
signal s_chk_vals		   : std_logic_vector(15 downto 0);
signal IP_chk_sum		   : std_logic_vector(15 downto 0);
signal sh_chk_en 		   : std_logic;         
signal calc_chk_en		: std_logic;
signal ld_p_chk_vals	   : std_logic;            --parallel load
signal chksum_done 	   : std_logic;

signal s_src_o          : t_wrf_source_out;
signal s_src_hdr_o 	   : t_wrf_source_out;
signal s_src_payload_o  : t_wrf_source_out;
signal s_src_padding_o  : t_wrf_source_out;

signal payload_cyc      : std_logic;
signal hdr_wait         : std_logic;
signal hdr_done         : std_logic;
signal s_ETH_end        : natural range 12 to 16;
signal nRst_conv        : std_logic;
signal conv_reset       : std_logic;		

begin

count_tx_bytes : process(clk_i)
begin
	if rising_edge(clk_i) then
		if (nRST_i = '0' or state = IDLE) then		
			byte_count <= 0;
		else		
			if(s_src_o.stb = '1' and s_src_o.cyc = '1' and src_i.stall = '0') then
				byte_count <= byte_count + 2;	
			end if;
		end if;		 
	end if;
end process;

nRst_conv <= nRst_i AND NOT conv_reset; 

-- source output mapping to source output signals
src_o.cyc <= '0' when state_mux = NONE
	else '1';
src_o.stb <= s_src_o.stb;
src_o.dat <= s_src_o.dat;
src_o.sel <= "11";
src_o.adr <= c_WRF_DATA;	
src_o.we <= '1';

-- source mux
MUX_TX : with state_mux select 
s_src_o	<= s_src_hdr_o 	   when HEADER,
		      s_src_payload_o   when PAYLOAD,
		      s_src_padding_o   when PADDING,
		      s_src_padding_o   when others;

-- wb_slave mux
MUX_WB : with state_mux select 
wb_slave_o.STALL <= conv_A.STALL when PAYLOAD,
                    '1'          when others; 

wb_slave_o.ACK <= conv_A.ACK;
wb_slave_o.ERR <= conv_A.ERR;
wb_slave_o.RTY <= '0';
wb_slave_o.INT <= '0';
wb_slave_o.DAT <= (others => '0');

PL_WAIT : with state_mux select 
payload_cyc <= wb_slave_i.CYC	when PAYLOAD,
               '0'            when others;

s_sh_hdr_en <= s_src_hdr_o.cyc and s_src_hdr_o.stb and not src_i.stall;
				
shift_hdr_chk_sum : piso_flag generic map( 96, 16, 1)
port map ( d_i         => p_chk_vals,
           q_o         => s_chk_vals,
           clk_i       => clk_i,
           nRST_i      => nRST_i,
           en_i        => sh_chk_en,
           ld_i       	=> ld_p_chk_vals, 
	        full_o	   => open,
	        empty_o		=> chksum_empty
);

p_chk_vals		<= x"C511" & IPV4_TX.SRC & IPV4_TX.DST & IPV4_TX.TOL;

chksum_generator: EB_checksum port map ( clk_i  => clk_i,
                              nRst_i => nRst_i,
                              en_i   => calc_chk_en,
                              data_i => s_chk_vals,
                              done_o => chksum_done,
                              sum_o  => IP_chk_sum );

Shift_out: piso_flag generic map (c_IPV4_HLEN*8, 16, 0)
                        port map ( d_i       => TX_HDR_slv,
                                   q_o       => s_src_hdr_o.DAT,
                                   clk_i     => clk_i,
                                   nRST_i    => nRST_i,
                                   en_i      => s_sh_hdr_en,
                                   ld_i      => ld_hdr, 
				                       full_o    => open,
				                       empty_o   => open);

-- convert streaming input from 16 to 32 bit data width
uut: WB_bus_adapter_streaming_sg generic map (   g_adr_width_A => 32,
                                                 g_adr_width_B => 2,
                                                 g_dat_width_A => 32,
                                                 g_dat_width_B => 16,
                                                 g_pipeline    =>  3)
                                      port map ( clk_i         => clk_i,
                                                 nRst_i        => nRst_conv,
                                                 A_CYC_i       => payload_cyc,
                                                 A_STB_i       => wb_slave_i.STB,
                                                 A_ADR_i       => wb_slave_i.ADR,
                                                 A_SEL_i       => wb_slave_i.SEL,
                                                 A_WE_i        => wb_slave_i.WE,
                                                 A_DAT_i       => wb_slave_i.DAT,
                                                 A_ACK_o       => conv_A.ACK,
                                                 A_ERR_o       => conv_A.ERR,
                                                 A_RTY_o       => conv_A.RTY,
                                                 A_STALL_o     => conv_A.STALL,
                                                 A_DAT_o       => conv_A.DAT,
                                                 B_CYC_o       => s_src_payload_o.cyc,
                                                 B_STB_o       => s_src_payload_o.stb,
                                                 B_ADR_o       => s_src_payload_o.adr,
                                                 B_SEL_o       => s_src_payload_o.sel,
                                                 B_WE_o        => open,
                                                 B_DAT_o       => s_src_payload_o.dat,
                                                 B_ACK_i       => src_i.ack,
                                                 B_ERR_i       => src_i.err,
                                                 B_RTY_i       => src_i.rty,
                                                 B_STALL_i     => src_i.stall,
                                                 B_DAT_i       => (others => '0')); 



															 
timeout : process(clk_i)
begin
	if rising_edge(clk_i) then
		--Counter: Timeout
		-- reset timeout if idle          
		if((nRST_i = '0') or (state = IDLE)) then
			 --s_timeout_cnt <= (others => '1');
			 s_timeout_cnt <= to_unsigned(5000, s_timeout_cnt'length);
		else
			 s_timeout_cnt <= s_timeout_cnt -1;  
		end if;
	end if;
end process;


main_fsm : process(clk_i)
begin
if rising_edge(clk_i) then

   --==========================================================================
   -- SYNC RESET                         
    --========================================================================== 
	if (nRST_i = '0') then
		ETH_TX 	         <= INIT_ETH_HDR (my_mac_i);
		IPV4_TX 	         <= INIT_IPV4_HDR(my_ip_i);
		UDP_TX 	         <= INIT_UDP_HDR (my_port_i);
      TX_HDR_slv        <= (others => '0');			
      
      state_mux		   <= NONE;
		ld_hdr 			   <= '0';
		ld_p_chk_vals	   <= '0';
		sh_chk_en		   <= '0';
		calc_chk_en 	   <= '0';
      s_src_hdr_o.cyc   <=	'1';
		s_src_hdr_o.stb   <=	'0';
		s_src_hdr_o.adr   <= (others => '0');
		s_src_hdr_o.we    <= '1';
		s_src_hdr_o.sel   <= (others => '1');	
      s_ETH_end         <= c_ETH_HLEN -2; 	                     
      conv_reset        <= '0';  
      s_src_padding_o   <= 	(cyc => '1',
                               stb => '0',
                               adr => (others => '0'),
                               sel => (others => '1'),
					                we => '1',
                               dat => x"9AD1");
	else
		
		if(a_timeout = "0") then	
			ld_hdr 			<= '0';
			ld_p_chk_vals	<= '0';
			sh_chk_en		<= '0';
			calc_chk_en		<= '0';
			conv_reset     <= '0';
			
         case state is
				when IDLE 			=> state_mux			<= NONE;
									      if(valid_i = '1' AND silent_i = '0') then
										      ETH_TX 				<= INIT_ETH_HDR (my_mac_i); --init all header blocks
										      IPV4_TX 			   <= INIT_IPV4_HDR(my_ip_i);
										      UDP_TX 				<= INIT_UDP_HDR (my_port_i);
		                              ETH_TX.DST  	   <= reply_MAC_i;
										      IPV4_TX.DST	      <= reply_IP_i;
										      IPV4_TX.TOL	      <= TOL_i;
										      UDP_TX.MLEN	      <= payload_len_i;	
										      UDP_TX.DST_PORT   <= reply_PORT_i;
										      ld_p_chk_vals	   <= '1';
										      state 	         <= CALC_CHKSUM;		
									      end if;
				
				when CALC_CHKSUM	=> if(chksum_empty = '0') then --calculate ip checksum
										      sh_chk_en      <= '1';
										      calc_chk_en 	<= '1';
									      else
										      if(chksum_done = '1') then
											      IPV4_TX.SUM	<= IP_chk_sum;
											      ld_hdr 	   <= '1';
											      state 	   <= WAIT_SEND_REQ;
												end if;
									      end if;	
				
				when WAIT_SEND_REQ   =>	if(silent_i = '1') then
									            state <= IDLE;
									         elsif(wb_slave_i.CYC = '1') then
									            state 		<= PREP_ETH;
									            state_mux	<= HEADER;
									         end if;	
									
				when PREP_ETH		=>	TX_HDR_slv(TX_HDR_slv'left downto TX_HDR_slv'length-c_ETH_HLEN*8) <= to_std_logic_vector(ETH_TX);
									      s_ETH_end   <= c_ETH_HLEN -2;
									      ld_hdr      <= '1';
								         state 		<= ETH;			
				  
				when ETH		      => s_src_hdr_o.stb <= '1';
							            if(byte_count = s_ETH_end and src_i.stall = '0') then
								            TX_HDR_slv        <= to_std_logic_vector(IPV4_TX);
								            ld_hdr            <= '1';									
								            state 		      <= IPV4;
								            s_src_hdr_o.stb   <= '0';
							            end if;

				when IPV4		   => s_src_hdr_o.stb <= '1';
							            if((byte_count = (s_ETH_end + c_IPV4_HLEN)) and src_i.stall = '0') then
								            TX_HDR_slv(TX_HDR_slv'left downto TX_HDR_slv'length-c_UDP_HLEN*8) <= to_std_logic_vector(UDP_TX);
								            ld_hdr            <= '1';									
								            state 		      <= UDP;
								            s_src_hdr_o.stb   <= '0';
							            end if;

				when UDP		      => s_src_hdr_o.stb <= '1';
							            if(byte_count = (s_ETH_end + c_IPV4_HLEN + c_UDP_HLEN) and src_i.stall = '0') then
								            state 		      <= HDR_SEND;
								            s_src_hdr_o.stb   <= '0';
							            end if;	
				
				when HDR_SEND		=> state_mux  	<= PAYLOAD;
								         state 	   <= PAYLOAD_SEND;		
								

				when PAYLOAD_SEND	=> if( s_src_payload_o.cyc = '0') then
									         if(byte_count  <  c_ETH_FRAME_MIN_END) then
										         state 		<= PADDING;
										         state_mux 	<= PADDING;	
									         elsif(byte_count  /= to_integer(unsigned(IPV4_TX.TOL)+14)) then
									           state 		   <= ERRORS;
									         else
										         state 		<= WAIT_IFGAP;
										         state_mux 	<= NONE;
									         end if;
								         end if;	
				
				when PADDING	   => s_src_padding_o.stb <= '1';
											if((byte_count  >=  c_ETH_FRAME_MIN_END) and src_i.stall = '0') then
								            s_src_padding_o.stb  <= '0'; 					
									         state 	            <= WAIT_IFGAP;
									         state_mux            <= NONE;	
								         end if;
				
				when WAIT_IFGAP	=>	state <= IDLE;
	
				when ERRORS       => state <= IDLE;		
                                 report ("TX: ERRORS - Wrong packet size. Expected " & integer'image(byte_count) &  " found " & integer'image(to_integer(unsigned(IPV4_TX.TOL)+14)))  severity error;  
				when others =>			state <= IDLE;			
			
			
			end case;
		
		else
			state <= IDLE;
			state_mux <= NONE;
			conv_reset <= '1';
		end if;
		
		
	end if;
end if;    
	
end process;



end behavioral;
