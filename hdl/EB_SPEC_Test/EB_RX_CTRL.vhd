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
use work.wb16_package.all;

entity EB_RX_CTRL is
  port(
    clk_i  : in std_logic;
    nRst_i : in std_logic;


    RX_slave_o : out wb16_slave_out;    --! Wishbone master output lines
    RX_slave_i : in  wb16_slave_in;     --!

    --Eth MAC WB Streaming signals
    wb_master_i : in  wb32_master_in;
    wb_master_o : out wb32_master_out;

    reply_MAC_o  : out std_logic_vector(6*8-1 downto 0);
    reply_IP_o   : out std_logic_vector(4*8-1 downto 0);
    reply_Port_o : out std_logic_vector(2*8-1 downto 0);
    TOL_o        : out std_logic_vector(2*8-1 downto 0);
    payload_len_o : out std_logic_vector(2*8-1 downto 0);
    
    my_mac_i  : in std_logic_vector(6*8-1 downto 0);
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

  signal conv_A : wb16_slave_out;       --! Wishbone master output lines
  signal conv_B : wb32_master_out;      --!


-- main FSM
  type   st is (IDLE, HDR_RECEIVE, CALC_CHKSUM, WAIT_STATE, CHECK_HDR, PAYLOAD_RECEIVE, error);
  signal state_RX : st := IDLE;
  type   st_hdr is (ETH, IPV4, UDP);
  signal state_HDR : st_hdr := ETH;

--split shift register output and convert to hdr records
  signal ETH_RX  : ETH_HDR;
  signal IPV4_RX : IPV4_HDR;
  signal UDP_RX  : UDP_HDR;
  signal payload_len : std_logic_vector(2*8-1 downto 0);

signal RX_HDR_slv : std_logic_vector(c_IPV4_HLEN*8-1 downto 0) 		;

--forking the bus
    type stmux is (HEADER, PAYLOAD);
  signal state_mux        : stmux := HEADER;
  signal RX_hdr_o         : wb16_slave_out;  --! Wishbone master output lines
  signal wb_payload_stb_o : wb32_master_out;

--shift register input and control signals
  signal counter_input : natural;
  signal counter_clr      : std_logic;
    signal hdr_done      : std_logic;

  signal sipo_clr      : std_logic;
  signal sipo_full     : std_logic;
  signal sipo_empty    : std_logic;
  signal sipo_en       : std_logic;



  signal PAYLOAD_STB_i : std_logic;
  signal PAYLOAD_CYC_i : std_logic;
  signal HDR_STALL : std_logic;
	


begin


  
  Shift_in : sipo_flag generic map (16, c_IPV4_HLEN*8) --IP header is longest possibility
    port map (d_i     => RX_slave_i.DAT,
              q_o     => RX_HDR_slv,
              clk_i   => clk_i,
              nRST_i  => nRST_i,
              en_i    => sipo_en,
              clr_i   => sipo_clr,
              full_o  => sipo_full,
              empty_o => sipo_empty);

  



  sh : sipo_en <= '1' when (RX_slave_i.CYC = '1' and RX_slave_i.STB = '1')
                  else '0';


-- convert streaming input from 16 to 32 bit data width
  uut : WB_bus_adapter_streaming_sg generic map (g_adr_width_A => 32,
                                                 g_adr_width_B => 32,
                                                 g_dat_width_A => 16,
                                                 g_dat_width_B => 32,
                                                 g_pipeline    => 3)
    port map (clk_i     => clk_i,
              nRst_i    => nRst_i,
              A_CYC_i   => PAYLOAD_CYC_i,
              A_STB_i   => PAYLOAD_STB_i,
              A_ADR_i   => RX_slave_i.ADR,
              A_SEL_i   => RX_slave_i.SEL,
              A_WE_i    => RX_slave_i.WE,
              A_DAT_i   => RX_slave_i.DAT,
              A_ACK_o   => conv_A.ACK,
              A_ERR_o   => conv_A.ERR,
              A_RTY_o   => conv_A.RTY,
              A_STALL_o => conv_A.STALL,
              A_DAT_o   => conv_A.DAT,
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



  RX_hdr_o.STALL <= HDR_STALL;
  
  MUX_RX : with state_mux select
    RX_slave_o <= conv_A when PAYLOAD,
    RX_hdr_o             when others;
  
  MUX_PAYLOADSTB : with state_mux select
    PAYLOAD_STB_i <= RX_slave_i.STB when PAYLOAD,
    '0'                             when others;

  MUX_PAYLOADCYC : with state_mux select
    PAYLOAD_CYC_i <= RX_slave_i.CYC when PAYLOAD,
    '0'                             when others;


  MUX_WB : with state_mux select
    wb_master_o <= conv_B when PAYLOAD,
    wb_payload_stb_o      when others;



--postpone VLAN support                     
  reply_MAC_o  <= ETH_RX.SRC;
  reply_IP_o   <= IPV4_RX.SRC;
  reply_PORT_o <= UDP_RX.SRC_PORT;
  payload_len_o <= payload_len;
  TOL_o        <= IPV4_RX.TOL;


count_bytes : process(clk_i)
begin
	if rising_edge(clk_i) then

      --==========================================================================
      -- SYNC RESET                         
      --========================================================================== 
      if (nRST_i = '0') then

       state_HDR     <= ETH;
		   counter_input  <= 0;
	     hdr_done <= '0';
	     state_mux <= HEADER;
	     HDR_STALL <= '0';	
	    else
	  
	  if(counter_clr  = '1') then
      state_HDR     <= ETH;
		   counter_input  <= 0;
	     hdr_done <= '0';
	     state_mux <= HEADER;	

	  end if;
	  
	 
	     
    if(state_RX = HDR_RECEIVE) then
			if(RX_slave_i.CYC = '1' and RX_slave_i.STB = '1') then
				counter_input <= counter_input +2;
				
			
			
			case state_HDR is
					when ETH => if(counter_input >= c_ETH_HLEN-2) then
							counter_input  <= 0;
							ETH_RX    <= TO_ETH_HDR(RX_HDR_slv(c_ETH_HLEN*8-1 downto 0));	
							state_HDR     <= IPV4;
						  end if;
					when IPV4 => if(counter_input >= c_IPV4_HLEN-2) then
							counter_input  <= 0;
							IPV4_RX    <= TO_IPV4_HDR(RX_HDR_slv(c_IPV4_HLEN*8-1 downto 0));	
							state_HDR     <= UDP;
						    end if;
					when UDP => 
					   if(counter_input = c_UDP_HLEN-4 AND (RX_slave_i.CYC = '1' and RX_slave_i.STB = '1')) then
					     HDR_STALL <= '1';
					   elsif(counter_input >= c_UDP_HLEN-2) then
							counter_input  <= 0;
							UDP_RX    <= TO_UDP_HDR(RX_HDR_slv(c_UDP_HLEN*8-1 downto 0));
							hdr_done <= '1';
							state_mux <= PAYLOAD;
							HDR_STALL <= '0';
   
						 end if;
					end case;
				end if;		
		end if;
						
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
        
        RX_hdr_o.ACK <= '0';

        RX_hdr_o.ERR <= '0';
        RX_hdr_o.DAT <= (others => '0');
        RX_hdr_o.RTY <= '0';

        wb_payload_stb_o.STB <= '0';
        wb_payload_stb_o.CYC <= '1';
        wb_payload_stb_o.WE  <= '1';
        wb_payload_stb_o.SEL <= (others => '1');
        wb_payload_stb_o.ADR <= (others => '0');
        wb_payload_stb_o.DAT <= (others => '0');


       
        payload_len <= (others => '0');

 
      else
        counter_clr <= '0';
        sipo_clr <= '0';
        RX_hdr_o.ACK <= '0';
        
        if(RX_slave_i.CYC = '1' and RX_slave_i.STB = '1') then
  				  RX_hdr_o.ACK <= '1';
        end if;
        
        
        if((RX_slave_i.CYC = '0') and not ((state_RX = PAYLOAD_RECEIVE) or (state_RX = IDLE))) then  --packet aborted before completion
          state_RX <= error;
        else
          
          case state_RX is
            when IDLE =>    counter_clr <= '1';
                            if(RX_slave_i.CYC = '1' and RX_slave_i.STB = '1' AND RX_slave_i.ADR(1 downto 0) = "00") then
  						                  state_RX      <= HDR_RECEIVE;
                            end if;
                         
            when HDR_RECEIVE =>	if(hdr_done = '1') then 
                                  state_RX <= PAYLOAD_RECEIVE;
                                  payload_len <= std_logic_vector(unsigned(UDP_RX.MLEN)-8);
                                  valid_o <= '1';
                                end if;  

                                      

            when PAYLOAD_RECEIVE => if(RX_slave_i.CYC = '0') then
                                      state_RX <= IDLE;
                                      sipo_clr <= '1';

                                    end if;
                                    
            when error => sipo_clr <= '1';
                          
                          state_rx <= IDLE;
                          
            when others => state_RX <= IDLE;
    
                           
                           
          end case;
          
        end if;
        
        
        
      end if;
    end if;
    
  end process;



end behavioral;
