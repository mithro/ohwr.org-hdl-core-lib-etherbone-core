--! @file eb_main_fsm.vhd
--! @brief EtherBone logic core
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
use work.eb_hdr_pkg.all;
use work.genram_pkg.all;
use work.wishbone_pkg.all;

entity eb_main_fsm is
  port(
    clk_i : in std_logic;  --! System Clk
    nRst_i : in std_logic;  --! active low sync reset

    --Eth MAC WB Streaming signals
    EB_RX_i : in t_wishbone_slave_in;  --! Streaming wishbone(record) sink from RX transport protocol block
    EB_RX_o : out t_wishbone_slave_out;  --! Streaming WB sink flow control to RX transport protocol block
    EB_TX_i : in t_wishbone_master_in;  --! Streaming WB src flow control from TX transport protocol block
    EB_TX_o : out t_wishbone_master_out;  --! Streaming WB src to TX transport protocol block
    TX_silent_o : out std_logic;
    byte_count_rx_i : in std_logic_vector(15 downto 0);  --! Payload byte length from RX transport protocol block
    --config signals

    config_master_i : in t_wishbone_master_in;  --! WB V4 interface to WB interconnect/device(s)
    config_master_o : out t_wishbone_master_out;  --! WB V4 interface to WB interconnect/device(s)
    WB_master_i : in t_wishbone_master_in;  --! WB V4 interface to WB interconnect/device(s)
    WB_master_o : out t_wishbone_master_out  --! WB V4 interface to WB interconnect/device(s)

    );
end eb_main_fsm;

architecture behavioral of eb_main_fsm is

--Signals
------------------------------------------------------------------------------------------
--State Machines
------------------------------------------------------------------------------------------
constant c_width_int : integer := 24;
type t_state_RX is (IDLE, EB_HDR_REC, EB_HDR_PROC, EB_HDR_PROBE_ID, EB_HDR_PROBE_RDY, CYC_HDR_REC, CYC_HDR_READ_PROC, CYC_HDR_READ_GET_ADR, WB_READ_RDY, WB_READ, CYC_HDR_WRITE_PROC, CYC_HDR_WRITE_GET_ADR, WB_WRITE_RDY, WB_WRITE, WB_WRITE_DONE, CYC_DONE, EB_DONE, ERRORS, ERROR_WAIT);
type t_state_TX is (IDLE, EB_HDR_INIT, EB_HDR_PROBE_ID, EB_HDR_PROBE_WAIT, PACKET_HDR_SEND, EB_HDR_SEND, RDY, CYC_HDR_INIT, CYC_HDR_SEND, BASE_WRITE_ADR_SEND, DATA_SEND, ZERO_PAD_WRITE, ZERO_PAD_WAIT, ERRORS);



signal s_state_RX : t_state_RX := IDLE;
signal s_state_TX : t_state_TX := IDLE;
constant test : std_logic_vector(31 downto 0) := (others => '0');

------------------------------------------------------------------------------------------
--Wishbone Interfaces 
------------------------------------------------------------------------------------------
signal s_WB_master_i : t_wishbone_master_in;
signal s_WB_master_o : t_wishbone_master_out;
signal s_config_master_i : t_wishbone_master_in;
signal s_config_master_o : t_wishbone_master_out;


signal s_WB_STB : std_logic;
signal s_WB_ADR : std_logic_vector(WB_master_o.ADR'left downto 0);
signal s_WB_SEL : std_logic_vector(WB_master_o.SEL'left downto 0);
signal s_WB_WE : std_logic;
signal s_TX_STROBED : std_logic;
signal s_WB_addr_inc : unsigned(c_EB_ADDR_SIZE_n-1 downto 0);
------------------------------------------------------------------------------------------
-- Byte/Pulse Counters
------------------------------------------------------------------------------------------
signal s_WB_wr_ack_cnt : unsigned(1+7 downto 0);
alias a_WB_wr_ack_cnt : unsigned(7 downto 0) is s_WB_wr_ack_cnt(7 downto 0);
signal s_WB_rd_ack_cnt : unsigned(1+7 downto 0);
alias a_WB_rd_ack_cnt : unsigned(7 downto 0) is s_WB_rd_ack_cnt(7 downto 0);
signal s_WB_ack_overflow : std_logic;
signal s_timeout_cnt : unsigned(14 downto 0);
alias a_timeout : unsigned(0 downto 0) is s_timeout_cnt(s_timeout_cnt'left downto s_timeout_cnt'left);
signal s_EB_probe_wait_cnt : unsigned(3 downto 0);
signal s_EB_TX_zeropad_cnt : unsigned(7 downto 0);
signal s_EB_RX_byte_cnt : unsigned(15 downto 0);
signal s_EB_RX_byte_cnt_idle_rst : std_logic;
signal s_EB_TX_byte_cnt : unsigned(15 downto 0);


------------------------------------------------------------------------------------------
--Config and Status Regs
------------------------------------------------------------------------------------------
signal s_WB_Config_o : t_wishbone_slave_out;
signal s_WB_Config_i : t_wishbone_slave_in;
signal s_ADR_CONFIG : std_logic;
signal s_RX_CYC_lowered : std_logic;


------------------------------------------------------------------------------------------
--Etherbone Signals
------------------------------------------------------------------------------------------
signal s_EB_RX_ACK : std_logic;
signal rx_stall : std_logic;
signal s_EB_TX_STB : std_logic;
signal sink_valid : std_logic;

------------------------------------------------------------------------------------------
--Etherbone Registers
------------------------------------------------------------------------------------------
constant c_WB_WORDSIZE : natural := 32;
constant c_EB_HDR_LEN : unsigned(3 downto 0) := x"0";
signal s_EB_TX_base_wr_adr : std_logic_vector(31 downto 0);
signal s_EB_packet_length : unsigned(15 downto 0);
signal s_EB_RX_HDR : EB_HDR;
signal s_EB_RX_CUR_CYCLE : EB_CYC;
signal s_EB_TX_HDR : EB_HDR;
signal s_EB_TX_CUR_CYCLE : EB_CYC;

------------------------------------------------------------------------------------------
--Etherbone FIFO Buffers
------------------------------------------------------------------------------------------
signal s_fifo_tx_am_full : std_logic;
signal s_fifo_tx_full : std_logic;
signal s_fifo_tx_empty : std_logic;
signal s_fifo_tx_data : std_logic_vector(31 downto 0);
signal s_fifo_tx_rd : std_logic;
signal s_fifo_tx_we : std_logic;
signal s_fifo_rx_am_full : std_logic;
signal s_fifo_rx_am_empty : std_logic;
signal s_fifo_rx_empty : std_logic;
signal s_fifo_rx_data : std_logic_vector(31 downto 0);
signal s_fifo_rx_q : std_logic_vector(31 downto 0);
signal s_fifo_rx_rd : std_logic;
signal s_fifo_rx_pop : std_logic;
signal s_fifo_rx_we : std_logic;
signal s_fifo_rx_gauge : std_logic_vector(3 downto 0);
------------------------------------------------------------------------------------------


signal PROBE_ID : std_logic_vector(31 downto 0);

constant WBM_Zero_o : t_wishbone_master_out := (CYC => '0',
                                                           STB => '0',
                                                           ADR => (others => '0'),
                                                           SEL => (others => '0'),
                                                           WE => '0',
                                                           DAT => (others => '0'));

constant WBS_Zero_o : t_wishbone_slave_out := (ACK => '0',
                                                          ERR => '0',
                                                          RTY => '0',
                                                          STALL => '0',
                                                          INT => '0',
                                                          DAT => (others => '0'));

function active_high (bool : boolean) return std_logic is
begin
  if(bool) then
    return '1';
  else
    return '0';
  end if;
end active_high;
-------------------------------------------------------------------------------
impure function wb_stb_wr_mid_packet
  return std_logic is
begin
   return ((not s_fifo_rx_am_empty and active_high(s_EB_RX_CUR_CYCLE.WR_CNT > 0)) or (s_WB_STB and s_WB_master_i.STALL));
end wb_stb_wr_mid_packet;

impure function wb_stb_wr_end_packet
  return std_logic is
begin
   return (not s_fifo_rx_empty and s_RX_CYC_lowered  and active_high(s_EB_RX_CUR_CYCLE.WR_CNT > 0)); --and active_high(s_EB_RX_byte_cnt = s_EB_packet_length)
end wb_stb_wr_end_packet;

impure function wb_stb_wr
  return std_logic is
begin
   return wb_stb_wr_mid_packet or wb_stb_wr_end_packet;
end wb_stb_wr;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
impure function wb_stb_rd_mid_packet
  return std_logic is
begin
   return (((not s_fifo_rx_am_empty and not s_fifo_tx_am_full)and active_high(s_EB_RX_CUR_CYCLE.RD_CNT > 0)) or (s_WB_STB and s_WB_master_i.STALL));
end wb_stb_rd_mid_packet;

impure function wb_stb_rd_end_packet
  return std_logic is
begin
   return ((not s_fifo_rx_empty and not s_fifo_tx_am_full) and s_RX_CYC_lowered and active_high(s_EB_RX_CUR_CYCLE.RD_CNT > 0) ); --and active_high(s_EB_RX_byte_cnt = s_EB_packet_length)
end wb_stb_rd_end_packet;

impure function wb_stb_rd
  return std_logic is
begin
   return wb_stb_rd_mid_packet or wb_stb_rd_end_packet;
end wb_stb_rd;
-------------------------------------------------------------------------------


begin

  TX_FIFO : generic_sync_fifo
    generic map (
      g_data_width => 32,
      g_size => 16,
      g_show_ahead => true,
      g_with_empty => true,
      g_with_full => true,
      g_with_almost_empty => true,
      g_with_almost_full => true,
      g_with_count => true,
      g_almost_empty_threshold => 1,
      g_almost_full_threshold => 11)
    port map (
      rst_n_i => nRst_i,
      clk_i => clk_i,
      d_i => s_fifo_tx_data,
      we_i => s_fifo_tx_we,
      q_o => EB_TX_o.DAT,
      rd_i => s_fifo_tx_rd,
      empty_o => s_fifo_tx_empty,
      full_o => s_fifo_tx_full,
      almost_empty_o => open,
      almost_full_o => s_fifo_tx_am_full,
      count_o => open);



--strobe out as long as there is data left    
EB_TX_o.STB <= NOT s_fifo_tx_empty;

--read data from RX fifo as long as TX interface is free
s_fifo_tx_rd <= NOT EB_TX_i.STALL;

--write in pending data as long as there is space left
s_fifo_tx_we <= s_EB_TX_STB;

RX_FIFO : generic_sync_fifo
  generic map (
      g_data_width => 32,
      g_size => 16,
      g_show_ahead => true,
      g_with_empty => true,
      g_with_full => true,
      g_with_almost_empty => true,
      g_with_almost_full => true,
      g_with_count => true,
      g_almost_empty_threshold => 1,
      g_almost_full_threshold => 11)
     port map (
      rst_n_i => nRst_i,
      clk_i => clk_i,
      d_i => s_fifo_rx_data,
      we_i => s_fifo_rx_we,
      q_o => s_fifo_rx_q,
      rd_i => s_fifo_rx_rd,
      empty_o => s_fifo_rx_empty,
      full_o => open,
      almost_empty_o => open,
      almost_full_o => s_fifo_rx_am_full,
      count_o => s_fifo_rx_gauge);




  s_fifo_rx_rd <= (not s_WB_master_i.STALL and s_WB_STB) or s_fifo_rx_pop;
  s_fifo_rx_data <= EB_RX_i.DAT;



--BUG: almost_empty flag is stuck after hitting empty repeatedly.
--create our own for now
  s_fifo_rx_am_empty <= '1' when unsigned(s_fifo_rx_gauge) <= 1
                        else '0';

  s_WB_master_o.DAT <= s_fifo_rx_q;
  s_WB_master_o.STB <= s_WB_STB and not s_ADR_CONFIG;
  s_WB_master_o.WE <= s_WB_WE;
  s_WB_master_o.SEL <= s_WB_SEL;
  s_WB_master_o.ADR <= s_fifo_rx_q when s_state_RX = WB_READ
                           else s_WB_ADR;
  WB_master_o <= s_WB_master_o;

  s_config_master_o.DAT <= s_fifo_rx_q;
  s_config_master_o.STB <= s_WB_STB and s_ADR_CONFIG;
  s_config_master_o.WE <= s_WB_WE;
  s_config_master_o.SEL <= s_WB_SEL;
  s_config_master_o.ADR <= s_fifo_rx_q when s_state_RX = WB_READ
                                   else s_WB_ADR;
  config_master_o <= s_config_master_o;

--when reading, incoming rx data goes on the WB address lines   
  EB_RX_o.STALL <= s_fifo_rx_am_full or rx_stall;
  EB_RX_o.ACK <= s_EB_RX_ACK;
  EB_RX_o.ERR <= '0';
  EB_RX_o.INT <= '0';
  EB_RX_o.RTY <= '0';
  EB_RX_o.DAT <= (others => '0');

s_fifo_rx_we <= EB_RX_i.STB AND NOT (s_fifo_rx_am_full or rx_stall);


--MUX lines: WB master / config space master
---------------------------------
Mux_WB_Cfg_in : with s_ADR_CONFIG select
s_WB_master_i <= config_master_i when '1',
                    WB_master_i when others;

-------------------------------------------------------------------------------
-- START COUNTERS
-------------------------------------------------------------------------------
  counters : process(clk_i)
  begin
    if rising_edge(clk_i) then

      if (nRST_i = '0') then
        s_EB_RX_byte_cnt          <= (others => '0');
        s_EB_TX_byte_cnt          <= (others => '0');
        s_WB_wr_ack_cnt           <= (others => '0');
        s_WB_rd_ack_cnt           <= (others => '0');
        s_timeout_cnt             <= (others => '0');
        s_EB_probe_wait_cnt       <= (others => '0');
        s_EB_RX_byte_cnt_idle_rst <= '1';
      else

        --Counter: RX bytes received
        if(s_state_RX = IDLE and s_EB_RX_byte_cnt_idle_rst = '1') then
          s_EB_RX_byte_cnt          <= (others => '0');
          s_EB_RX_byte_cnt_idle_rst <= '0';
        else
          if(s_fifo_rx_we = '1') then
            s_EB_RX_byte_cnt <= s_EB_RX_byte_cnt + 4;
          end if;
          if(s_state_RX /= IDLE) then
            s_EB_RX_byte_cnt_idle_rst <= '1';
          end if;
        end if;

        --Counter: TX bytes sent
        if(s_state_TX = IDLE) then
          s_EB_TX_byte_cnt <= (others => '0');
        else
          if(s_EB_TX_STB = '1' and s_fifo_tx_full = '0') then
            s_EB_TX_byte_cnt <= s_EB_TX_byte_cnt + 4;
          end if;
        end if;

        --Counter: WB ACKs or ERRs received 
        if(s_state_RX = IDLE) then
          s_WB_wr_ack_cnt <= (others => '0');
          s_WB_rd_ack_cnt <= (others => '0');
        else
          if(s_state_RX = CYC_HDR_WRITE_PROC) then
            s_WB_wr_ack_cnt <= '0' & s_EB_RX_CUR_CYCLE.WR_CNT;
            s_WB_rd_ack_cnt <= '0' & s_EB_RX_CUR_CYCLE.RD_CNT;
          else
            if(s_WB_master_i.ACK = '1' or s_WB_master_i.ERR = '1') then
              if(s_state_RX = WB_WRITE or s_state_RX = WB_WRITE_DONE) then
                s_WB_wr_ack_cnt <= s_WB_wr_ack_cnt -1;
              end if;
              if(s_state_RX = WB_READ or s_state_RX = CYC_DONE) then
                s_WB_rd_ack_cnt <= s_WB_rd_ack_cnt -1;
              end if;
            end if;
          end if;
        end if;

        --Counter: Probewait
        if(s_state_TX = EB_HDR_PROBE_ID) then
          s_EB_probe_wait_cnt <= (others => '0');
        else
          if(s_state_TX = EB_HDR_PROBE_WAIT) then
            s_EB_probe_wait_cnt <= s_EB_probe_wait_cnt +1;
          end if;
        end if;

        ---Counter: Timeout            
        if(s_state_RX = IDLE) then
          s_timeout_cnt                     <= to_unsigned(3000, s_timeout_cnt'length);
          s_timeout_cnt(s_timeout_cnt'left) <= '0';
        else
          if(s_RX_CYC_lowered = '1') then
            s_timeout_cnt <= s_timeout_cnt -1;
          end if;
        end if;

      end if;
    end if;
  end process;

-- this checks if there were too many acks from the WB slave
s_WB_ack_overflow <= s_WB_wr_ack_cnt(s_WB_wr_ack_cnt'left) or s_WB_rd_ack_cnt(s_WB_rd_ack_cnt'left);

-------------------------------------------------------------------------------
-- END COUNTERS
-------------------------------------------------------------------------------
p_state_transition : process(clk_i)
begin
  if rising_edge(clk_i) then
    if (nRST_i = '0') then
      s_state_TX <= IDLE;
      s_state_RX <= IDLE;
    else
if(a_timeout = "1" AND (s_state_RX /= ERROR_WAIT) AND (s_state_RX /= ERRORS)) then
        report "EB: Timeout, core stuck too long. Could be a malformed packet or an unresponsive WB target." severity note;
        s_state_RX <= ERRORS;
        s_state_TX <= IDLE;
      else
        case s_state_RX is
          when IDLE => --start if there is data in the input buffer  
                       if(s_fifo_rx_empty = '0') then
                         s_state_TX <= IDLE;
                         s_state_RX <= EB_HDR_REC;
                         report "EB: PACKET START" severity note;
                       end if;

          when EB_HDR_REC => if(s_fifo_rx_empty = '0') then
                               s_state_RX <= EB_HDR_PROC;
                             end if;

          when EB_HDR_PROC => if (s_EB_RX_HDR.EB_MAGIC /= c_EB_MAGIC_WORD)  -- not EB
                              then  --this is either not an EB packet or incompatible EB format. Abort.                                                             
                                s_state_RX <= ERRORS;
                                report "EB: NO ETHERBONE PACKET" severity note;
                              else
                                        --EB hdr seems valid. continue
                                if(s_EB_RX_HDR.PROBE = '1') then  --Is this a probe packet? 
                                  --prepare EB header with probe response and probe ID                                                                 
                                  s_state_RX <= EB_HDR_PROBE_ID;
                                  s_state_TX <= EB_HDR_INIT;
                                else
                                  if(((s_EB_RX_HDR.ADDR_SIZE and c_MY_EB_ADDR_SIZE) = x"0")
                                     or ((s_EB_RX_HDR.PORT_SIZE and c_MY_EB_PORT_SIZE) = x"0")
                                     or (s_EB_RX_HDR.VER /= c_EB_VER)) then
                                    s_state_RX <= ERRORS;
                                    report "EB: Incompatible EB Version or Parameters" severity note;
                                  else
                                    --Is a response expected? if so, prepare etherbone header

                                    if(s_EB_RX_HDR.NO_RESPONSE = '0')
                                    then
                                      s_state_TX <= EB_HDR_INIT;
                                    else
                                      s_state_TX <= RDY;
                                    end if;
                                    s_state_RX <= CYC_HDR_REC;
                                  end if;
                                end if;
                              end if;

          when EB_HDR_PROBE_ID => if(s_fifo_rx_empty = '0') then  --read in probe ID 
                                    s_state_RX <= EB_HDR_PROBE_RDY;
                                  end if;

          when EB_HDR_PROBE_RDY => if(s_state_TX = RDY) then
                                     s_state_RX <= EB_DONE;
                                   end if;


                    when CYC_HDR_REC => if(s_fifo_rx_empty = '0') then
                                                            s_state_RX <= CYC_HDR_WRITE_PROC;
                                                    end if;

                    when CYC_HDR_WRITE_PROC => if(s_EB_RX_CUR_CYCLE.WR_CNT > 0) then
                                                        s_state_RX <= CYC_HDR_WRITE_GET_ADR;
                                                    else
                                                        s_state_RX <= CYC_HDR_READ_PROC;
                                                    end if;


                    when CYC_HDR_WRITE_GET_ADR => if(s_fifo_rx_empty = '0') then
                                                        s_state_RX <= WB_WRITE_RDY;
                                                    end if;

                    when WB_WRITE_RDY => if(s_state_TX = RDY) then

							s_state_RX <= WB_WRITE;

							if(s_EB_RX_HDR.NO_RESPONSE = '0') then
								s_state_TX <= ZERO_PAD_WRITE;
							else
								s_state_TX <= RDY;
							end if;

                                                    end if;

                    when WB_WRITE => if(s_EB_RX_CUR_CYCLE.WR_CNT = 0 and s_WB_STB = '0') then  --underflow of RX_cyc_wr_count
                                                        s_state_RX <= WB_WRITE_DONE;  --
                                                    end if;


                    when WB_WRITE_DONE => if(a_WB_wr_ack_cnt = 0) then
                                                      s_state_RX <= CYC_HDR_READ_PROC;
                                                    end if;

                    when CYC_HDR_READ_PROC => if(s_state_TX = RDY) then
                                                        --are there reads to do?

                                                        if(s_EB_RX_CUR_CYCLE.RD_CNT > 0) then


								if(s_EB_RX_HDR.NO_RESPONSE = '0') then
									 s_state_TX <= CYC_HDR_INIT;
								else
									s_state_TX <= RDY;
								end if;

                                                            s_state_RX <= CYC_HDR_READ_GET_ADR;
                                                        else
                                                            s_state_RX <= CYC_DONE;
                                                        end if;

                                                    end if;

                    when CYC_HDR_READ_GET_ADR => if(s_fifo_rx_empty = '0') then
                                                        s_state_RX <= WB_READ_RDY;
                                                    end if;

                    when WB_READ_RDY => if(s_state_TX = RDY) then
                                                        s_state_RX <= WB_READ;

							if(s_EB_RX_HDR.NO_RESPONSE = '0') then
								s_state_TX <= BASE_WRITE_ADR_SEND;
							else
								s_state_TX <= RDY;
							end if;

                                                    end if;

                    when WB_READ => if(s_EB_RX_CUR_CYCLE.RD_CNT = 0 and s_WB_STB = '0') then
                                                        s_state_RX <= CYC_DONE;
                                                    end if;

                  when CYC_DONE =>
                      if((s_WB_wr_ack_cnt = 0) and (s_WB_rd_ack_cnt = 0) and (s_fifo_tx_we = '0')) then
                        if( (s_RX_CYC_lowered = '0') or ((s_RX_CYC_lowered = '1') and (s_fifo_rx_empty = '0'))) then 
                           s_state_RX <= CYC_HDR_REC;  --more stuff to process. read next cycle  
                        else
                          if(s_fifo_tx_empty = '1') then
                            s_state_RX <= EB_DONE;  --no more cycles to do, packet is done.
                          end if;
                        end if;
                      elsif(s_WB_ack_overflow = '1') then
                        s_state_RX <= ERRORS;
                      end if;


                    when EB_DONE => if(((s_state_TX = IDLE) OR (s_state_TX = RDY)) and s_fifo_rx_empty = '1' and s_fifo_tx_empty = '1') then  -- 1. packet done, 2. probe done
                                                        s_state_RX <= IDLE;
                                                        s_state_TX <= IDLE;
                                                        if(s_EB_RX_byte_cnt /= s_EB_TX_byte_cnt) then
                                                          report ("EB: TX / RX mismatch. Expected " & integer'image(to_integer(s_EB_RX_byte_cnt)) & " found " & integer'image(to_integer(s_EB_TX_byte_cnt))) severity ERROR;

                                                        else
                                                          report "EB: PACKET COMPLETE" severity note;
                                                        end if;

                                                    end if;

                    when ERRORS => s_state_RX <= ERROR_WAIT;
                                                    s_state_TX <= IDLE;


                    when ERROR_WAIT => s_state_RX <= IDLE;

                    when others => s_state_RX <= IDLE;
                end case;


                case s_state_TX is
                    when IDLE => null;

                    when RDY => null;  --wait

                    when EB_HDR_INIT => s_state_TX <= PACKET_HDR_SEND;

                    when PACKET_HDR_SEND => s_state_TX <= EB_HDR_SEND;

                    --TODO: padding to 64bit alignment
                    when EB_HDR_SEND => if(s_fifo_tx_full = '0') then
                                                        if(s_EB_RX_HDR.PROBE = '1') then
                                                            s_state_TX <= EB_HDR_PROBE_ID;
                                                        else
                                                            s_state_TX <= RDY;
                                                        end if;
                                                    end if;

                    when EB_HDR_PROBE_ID => s_state_TX <= EB_HDR_PROBE_WAIT;




                    when EB_HDR_PROBE_WAIT => if(s_EB_probe_wait_cnt > 3 AND s_fifo_tx_empty = '1') then
                                                      s_state_TX <= RDY;
                                                    end if;



                    when CYC_HDR_INIT => s_state_TX <= CYC_HDR_SEND;

                    when CYC_HDR_SEND => if(s_fifo_tx_full = '0') then
                                                        s_state_TX <= RDY;
                                                    end if;

                    when BASE_WRITE_ADR_SEND => if(s_fifo_tx_full = '0') then
                                                        s_state_TX <= DATA_SEND;
                                                    end if;

                    when DATA_SEND =>  --only write at the moment!
                                                    if(s_EB_TX_CUR_CYCLE.WR_CNT = 0) then
                                                        s_state_TX <= RDY;
                                                    end if;

                    when ZERO_PAD_WRITE => if(s_EB_TX_zeropad_cnt = 0) then
                                                        s_state_TX <= RDY;
                                                    end if;

                    when ZERO_PAD_WAIT => null;

                    when others => s_state_TX <= IDLE;
                end case;

            end if;

        end if;
    end if;

end process p_state_transition;

p_state_output : process(clk_i)
begin
    if rising_edge(clk_i) then

    --==========================================================================
    -- SYNC RESET
--==========================================================================

        if (nRST_i = '0') then

			s_EB_TX_HDR <= init_EB_HDR;
			PROBE_ID <= X"1337BEEF";
			s_EB_TX_CUR_CYCLE <= INIT_EB_CYC;
			s_EB_RX_CUR_CYCLE <= INIT_EB_CYC;
			s_EB_TX_base_wr_adr <= (others => '0');

			s_EB_RX_ACK <= '0';


			EB_TX_o.CYC <= '0';

			EB_TX_o.ADR <= (others => '0');
			EB_TX_o.SEL <= (others => '1');

			EB_TX_o.WE <= '1';
			TX_silent_o <= '0';




			--s_EB_packet_length <= (others => '0');
			s_ADR_CONFIG <= '0';


			s_WB_master_o.CYC <= '0';
			s_config_master_o.CYC <= '0';
			s_WB_STB <= '0';
			s_WB_WE <= '0';
			s_WB_SEL <= (others => '1');
			s_WB_ADR <= (others => '0');

			s_EB_TX_zeropad_cnt <= (others => '0');
         s_RX_CYC_lowered <= '1'; 
		else


			s_EB_RX_ACK <= s_fifo_rx_we;  
         s_fifo_rx_pop <= '0';
			s_WB_WE <= '0';
			s_WB_STB <= '0';
			s_EB_TX_STB <= '0';

         if(EB_RX_i.CYC = '0') then
            s_RX_CYC_lowered <= '1';
            rx_stall <= '1';
         end if; 



            case s_state_RX is
                when IDLE => s_EB_RX_CUR_CYCLE <= INIT_EB_CYC;
                                                  rx_stall <= '0';          
                                               
                                                       

                when EB_HDR_REC => s_RX_CYC_lowered <= '0'; 
                                                s_EB_RX_HDR <= to_EB_HDR(s_fifo_rx_q);
                                                s_fifo_rx_pop <= '1';


                when EB_HDR_PROC => TX_silent_o <= s_EB_RX_HDR.NO_RESPONSE;


                when EB_HDR_PROBE_ID => PROBE_ID <= s_fifo_rx_q;
                                                s_fifo_rx_pop <= '1';

                when EB_HDR_PROBE_RDY => null;


                when CYC_HDR_REC => s_EB_RX_CUR_CYCLE <= TO_EB_CYC(s_fifo_rx_q);
                                                s_fifo_rx_pop <= '1';


                when CYC_HDR_WRITE_PROC => if(s_EB_RX_CUR_CYCLE.WR_CNT > 0) then
                                                --setup word counters
                                                    s_ADR_CONFIG <= s_EB_RX_CUR_CYCLE.WCA_CFG;
                                                end if;


                when CYC_HDR_WRITE_GET_ADR => s_WB_ADR <= s_fifo_rx_q;
                                                s_fifo_rx_pop <= '1';  -- only stall RX if we got an adress, otherwise continue listening


                when WB_WRITE_RDY => if(s_state_TX = RDY) then
                                                    s_WB_master_o.CYC <= s_WB_master_o.CYC OR NOT s_ADR_CONFIG;
						    s_config_master_o.CYC <= s_config_master_o.CYC OR s_ADR_CONFIG;
                                                    s_WB_SEL <= s_EB_RX_CUR_CYCLE.SEL;

                                                    if(s_EB_RX_CUR_CYCLE.RD_CNT > 0) then
                                                        s_EB_TX_zeropad_cnt <= s_EB_RX_CUR_CYCLE.WR_CNT+1;  --wr start addr
                                                    else
                                                        s_EB_TX_zeropad_cnt <= s_EB_RX_CUR_CYCLE.WR_CNT+2;  --wr start addr + header because read block is not called
                                                    end if;
                                                end if;

              when WB_WRITE => s_WB_WE <= '1';
                               s_fifo_rx_pop <= '0';
                               s_WB_STB <= wb_stb_wr;

                               if((s_WB_STB = '1' and s_WB_master_i.STALL = '0') and (s_EB_RX_CUR_CYCLE.WR_FIFO = '0')) then
                                     s_WB_ADR <= std_logic_vector(unsigned(s_WB_ADR) + 4);
                               end if;

                               --this works slightly different than the actual
                               --pop of rx_fifo, because we go from n..0, not
                               --from n-1..0!
                               if(wb_stb_wr = '1' and not (s_WB_STB = '1' and s_WB_master_i.STALL = '1')) then

                                   s_EB_RX_CUR_CYCLE.WR_CNT <= s_EB_RX_CUR_CYCLE.WR_CNT-1;

                               end if;

		         when WB_WRITE_DONE => null;



               when CYC_HDR_READ_PROC => if(s_state_TX = RDY) then
                                                    --are there reads to do?

                                                    if(s_EB_RX_CUR_CYCLE.RD_CNT > 0) then
                                                        --setup word counters
                                                        s_ADR_CONFIG <= s_EB_RX_CUR_CYCLE.RCA_CFG;

                                                    end if;

                                                end if;

                when CYC_HDR_READ_GET_ADR =>  --wait for ready from tx output
                                                    s_EB_TX_base_wr_adr <= s_fifo_rx_q;
                                                    s_fifo_rx_pop <= '1';



                when WB_READ_RDY => if(s_state_TX = RDY) then
                                                    s_WB_master_o.CYC <= s_WB_master_o.CYC OR NOT s_ADR_CONFIG;
						    s_config_master_o.CYC <= s_config_master_o.CYC OR s_ADR_CONFIG;
                                                    s_WB_SEL <= s_EB_RX_CUR_CYCLE.SEL;
                                                end if;

              when WB_READ => if((s_state_TX = DATA_SEND) or (s_EB_RX_HDR.NO_RESPONSE = '1')) then
                                 s_WB_ADR <= s_fifo_rx_q;
                                 s_fifo_rx_pop <= '0';
                                 s_WB_STB <= wb_stb_rd;

                                 if(wb_stb_rd = '1' and not (s_WB_STB = '1' and s_WB_master_i.STALL = '1')) then
                                    s_EB_RX_CUR_CYCLE.RD_CNT <= s_EB_RX_CUR_CYCLE.RD_CNT-1;
                                 end if;
                              end if;



                when CYC_DONE => if((s_WB_wr_ack_cnt = 0) and (s_WB_rd_ack_cnt = 0) and (s_fifo_tx_we = '0')) then
                                        --keep cycle line high if no drop requested
                                    if(s_ADR_CONFIG = '0') then
	                                    s_WB_master_o.CYC <= NOT s_EB_RX_CUR_CYCLE.DROP_CYC;
                                    else
	                                    s_config_master_o.CYC <= NOT s_EB_RX_CUR_CYCLE.DROP_CYC;
                                    end if;
                                 end if;

                when EB_DONE =>  --report "EB: PACKET COMPLETE" severity note;
                                                --TODO: test multi packet mode
                                                s_WB_master_o.CYC <= '0';
																s_config_master_o.CYC <= '0';



                                                

                when ERRORS => report "EB: ERROR" severity warning;
                                                s_WB_master_o.CYC <= '0';
																s_config_master_o.CYC <= '0';
                                                s_EB_packet_length <= (others => '0');


                when others => null;
            end case;






            case s_state_TX is
                when IDLE => EB_TX_o.CYC <= '0';

                when RDY => null;       --wait

                when EB_HDR_INIT       => s_EB_TX_HDR <= init_EB_hdr;
                                          s_EB_TX_HDR.PROBE_RES <= s_EB_RX_HDR.PROBE;


                when PACKET_HDR_SEND   => EB_TX_o.CYC <= '1';
                when EB_HDR_SEND       => s_EB_TX_STB <= '1';
                                          s_fifo_tx_data <= to_std_logic_vector(s_EB_TX_HDR);

                when EB_HDR_PROBE_ID   => s_EB_TX_STB <= '1';
                                          s_fifo_tx_data <= PROBE_ID;


                when CYC_HDR_INIT      => s_EB_TX_CUR_CYCLE.WCA_CFG <= s_EB_RX_CUR_CYCLE.BCA_CFG;
                                          s_EB_TX_CUR_CYCLE.RD_FIFO <= '0';
                                          s_EB_TX_CUR_CYCLE.RD_CNT  <= (others => '0');
                                          s_EB_TX_CUR_CYCLE.WR_FIFO <= s_EB_RX_CUR_CYCLE.RD_FIFO;
                                          s_EB_TX_CUR_CYCLE.WR_CNT  <= s_EB_RX_CUR_CYCLE.RD_CNT;
                                          s_EB_TX_CUR_CYCLE.SEL     <= s_EB_RX_CUR_CYCLE.SEL;

                when CYC_HDR_SEND      => s_fifo_tx_data <= TO_STD_LOGIC_VECTOR(s_EB_TX_CUR_CYCLE);
                                          s_EB_TX_STB <= '1';

                when BASE_WRITE_ADR_SEND  =>  s_EB_TX_STB <= '1';
                                                s_fifo_tx_data <= s_EB_TX_base_wr_adr;

                when DATA_SEND            =>    s_fifo_tx_data <= s_WB_master_i.DAT;
                                                s_EB_TX_STB <= s_WB_master_i.ACK OR s_WB_master_i.ERR;
                                                if(s_WB_master_i.ACK = '1' or s_WB_master_i.ERR = '1') then
                                                    s_EB_TX_CUR_CYCLE.WR_CNT <= s_EB_TX_CUR_CYCLE.WR_CNT-1;
                                                end if;

                when ZERO_PAD_WRITE       =>    s_fifo_tx_data <= (others => '0');
                                                if(s_fifo_tx_am_full = '0' and s_EB_TX_zeropad_cnt > 0) then
                                                    s_EB_TX_zeropad_cnt <= s_EB_TX_zeropad_cnt -1;
                                                    s_EB_TX_STB         <= '1';
                                                end if;
                                        

                when ZERO_PAD_WAIT => null;

                when others => null;
            end case;
        end if;
    end if;

end process p_state_output;





end behavioral;

