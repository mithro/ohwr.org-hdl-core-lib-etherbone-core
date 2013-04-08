--! @file eb_slave_core.vhd
--! @brief Top file for EtherBone core
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

--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.etherbone_pkg.all;
use work.eb_hdr_pkg.all;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;
use work.eb_internals_pkg.all;


entity eb_slave_core is
  generic(g_sdb_address : std_logic_vector(63 downto 0) := x"01234567ABCDEF00");
  port
    (
      clk_i  : in std_logic;            --! clock input
      nRst_i : in std_logic;

      -- EB streaming sink -----------------------------------------
      snk_i : in  t_wrf_sink_in;
      snk_o : out t_wrf_sink_out;
      --------------------------------------------------------------

      -- EB streaming source ---------------------------------------
      src_o : out t_wrf_source_out;
      src_i : in  t_wrf_source_in;
      --------------------------------------------------------------

      -- WB slave - Cfg IF -----------------------------------------
      cfg_slave_o : out t_wishbone_slave_out;
      cfg_slave_i : in  t_wishbone_slave_in;

      -- WB master - Bus IF ----------------------------------------
      master_o : out t_wishbone_master_out;
      master_i : in  t_wishbone_master_in
      --------------------------------------------------------------

      );
end eb_slave_core;


architecture behavioral of eb_slave_core is


  signal DEBUG_WB_master_o : t_wishbone_master_out;
  signal WB_master_i       : t_wishbone_master_in;


-- int eb if to cfg space
  signal eb_2_CFG_slave : t_wishbone_slave_in;
  signal CFG_2_eb_slave : t_wishbone_slave_out;


-- ext if to cfg space
  signal EXT_2_CFG_slave : t_wishbone_slave_in;
  signal CFG_2_EXT_slave : t_wishbone_slave_out;

  signal CFG_MY_MAC  : std_logic_vector(6*8-1 downto 0);
  signal CFG_MY_IP   : std_logic_vector(4*8-1 downto 0);
  signal CFG_MY_PORT : std_logic_vector(2*8-1 downto 0);

-- TX CTRL  <-> EBCORE signals

  signal EB_2_TXCTRL_wb_slave : t_wishbone_slave_in;
  signal TXCTRL_2_EB_wb_slave : t_wishbone_slave_out;

  signal EB_2_RXCTRL_wb_master : t_wishbone_master_in;
  signal RXCTRL_2_EB_wb_master : t_wishbone_master_out;

-- RX CTRL <-> TXCTRL signals
  signal RXCTRL_2_TXCTRL_reply_MAC  : std_logic_vector(47 downto 0);
  signal RXCTRL_2_TXCTRL_reply_IP   : std_logic_vector(31 downto 0);
  signal RXCTRL_2_TXCTRL_reply_PORT : std_logic_vector(15 downto 0);
  signal RXCTRL_2_TXCTRL_TOL        : std_logic_vector(15 downto 0);
  signal RXCTRL_2_CORE_LEN          : std_logic_vector(15 downto 0);
  signal RXCTRL_2_TXCTRL_valid      : std_logic;

--EB <-> TXCTRL
  signal EB_2_TXCTRL_wb_master : t_wishbone_master_out;
  signal TXCTRL_2_EB_wb_master : t_wishbone_master_in;

--EB <-> RXCTRL
  signal EB_2_RXCTRL_wb_slave : t_wishbone_slave_out;
  signal RXCTRL_2_EB_wb_slave : t_wishbone_slave_in;

  signal EB_RX_i : t_wrf_sink_in;
  signal EB_RX_o : t_wrf_sink_out;

  signal EB_TX_i : t_wrf_source_in;
  signal EB_TX_o : t_wrf_source_out;

  signal EB_2_TXCTRL_silent : std_logic;

begin

  -- EB type conversions for WB daisychain
  EB_2_TXCTRL_wb_slave  <= t_wishbone_slave_in(EB_2_TXCTRL_wb_master);
  TXCTRL_2_EB_wb_master <= t_wishbone_master_in(TXCTRL_2_EB_wb_slave);

  EB_2_RXCTRL_wb_master <= t_wishbone_master_in(EB_2_RXCTRL_wb_slave);
  RXCTRL_2_EB_wb_slave  <= t_wishbone_slave_in(RXCTRL_2_EB_wb_master);

-- assign records to individual bus signals.


  master_o.cyc      <= DEBUG_WB_master_o.CYC;
  master_o.we       <= DEBUG_WB_master_o.WE;
  master_o.stb      <= DEBUG_WB_master_o.STB;
  master_o.sel      <= DEBUG_WB_master_o.SEL;
  master_o.adr      <= DEBUG_WB_master_o.ADR;
  master_o.dat      <= DEBUG_WB_master_o.DAT;
  WB_master_i.DAT   <= master_i.dat;
  WB_master_i.STALL <= master_i.stall;
  WB_master_i.ACK   <= master_i.ack;
  WB_master_i.ERR   <= master_i.err;
  WB_master_i.INT   <= '0';
  WB_master_i.RTY   <= '0';


-- ext interface to cfg space
  EXT_2_CFG_slave.CYC <= cfg_slave_i.cyc;
  EXT_2_CFG_slave.STB <= cfg_slave_i.stb;
  EXT_2_CFG_slave.WE  <= cfg_slave_i.we;
  EXT_2_CFG_slave.SEL <= cfg_slave_i.sel;
  EXT_2_CFG_slave.ADR <= cfg_slave_i.adr;
  EXT_2_CFG_slave.DAT <= cfg_slave_i.dat;
  cfg_slave_o.ack     <= CFG_2_EXT_slave.ACK;
  cfg_slave_o.stall   <= CFG_2_EXT_slave.STALL;
  cfg_slave_o.err     <= CFG_2_EXT_slave.ERR;
  cfg_slave_o.dat     <= CFG_2_EXT_slave.DAT;
  cfg_slave_o.int     <= '0';
  cfg_slave_o.rty     <= '0';


  TXCTRL : EB_TX_CTRL
    port map
    (
      clk_i  => clk_i,
      nRST_i => nRst_i,

      --Eth MAC WB Streaming signals
      wb_slave_i => EB_2_TXCTRL_wb_slave,
      wb_slave_o => TXCTRL_2_EB_wb_slave,

      src_o => src_o,
      src_i => src_i,                   --!

      reply_MAC_i  => RXCTRL_2_TXCTRL_reply_MAC,
      reply_IP_i   => RXCTRL_2_TXCTRL_reply_IP,
      reply_PORT_i => RXCTRL_2_TXCTRL_reply_PORT,

      TOL_i         => RXCTRL_2_TXCTRL_TOL,
      payload_len_i => RXCTRL_2_CORE_LEN,

      my_mac_i  => CFG_MY_MAC,
      my_ip_i   => CFG_MY_IP,
      my_port_i => CFG_MY_PORT,
      my_vlan_i => (others => '0'),
      silent_i  => EB_TX_o.cyc,
      valid_i   => RXCTRL_2_TXCTRL_valid

      );


  RXCTRL : EB_RX_CTRL
    port map (clk_i        => clk_i,
               nRst_i      => nRst_i,
               wb_master_i => EB_2_RXCTRL_wb_master,
               wb_master_o => RXCTRL_2_EB_wb_master,

               snk_o => snk_o,
               snk_i => snk_i,

               reply_MAC_o   => RXCTRL_2_TXCTRL_reply_MAC,
               reply_IP_o    => RXCTRL_2_TXCTRL_reply_IP,
               reply_PORT_o  => RXCTRL_2_TXCTRL_reply_PORT,
               TOL_o         => RXCTRL_2_TXCTRL_TOL,
               payload_len_o => RXCTRL_2_CORE_LEN,
               my_mac_i      => CFG_MY_MAC,
               my_ip_i       => CFG_MY_IP,
               my_port_i     => CFG_MY_PORT,
               my_vlan_i     => (others => '0'),
               valid_o       => RXCTRL_2_TXCTRL_valid);




  EB : eb_slave
    generic map(
      g_sdb_address => g_sdb_address(31 downto 0))
    port map(
      --general
      clk_i  => clk_i,
      nRst_i => nRst_i,

      --Eth MAC WB Streaming signals
      EB_RX_i => RXCTRL_2_EB_wb_slave,
      EB_RX_o => EB_2_RXCTRL_wb_slave,
      EB_TX_i => TXCTRL_2_EB_wb_master,
      EB_TX_o => EB_2_TXCTRL_wb_master,

      WB_config_i => EXT_2_CFG_slave,
      WB_config_o => CFG_2_EXT_slave,
      WB_master_i => WB_master_i,
      WB_master_o => DEBUG_WB_master_o,
      
      my_mac_o  => CFG_MY_MAC,
      my_ip_o   => CFG_MY_IP,
      my_port_o => CFG_MY_PORT);

end behavioral;
