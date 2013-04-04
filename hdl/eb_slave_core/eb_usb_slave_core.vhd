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


entity eb_usb_slave_core is
  generic(g_sdb_address : std_logic_vector(63 downto 0) := x"01234567ABCDEF00");
  port
    (
      clk_i  : in std_logic;            --! clock input
      nRst_i : in std_logic;

      -- EB streaming sink -----------------------------------------
      snk_i : in  t_wishbone_slave_in;
      snk_o : out t_wishbone_slave_out;
      --------------------------------------------------------------

      -- EB streaming source ---------------------------------------
      src_o : out t_wishbone_master_out;
      src_i : in  t_wishbone_master_in;
      --------------------------------------------------------------
      
      -- WB slave - Cfg IF -----------------------------------------
      cfg_slave_o : out t_wishbone_slave_out;
      cfg_slave_i : in  t_wishbone_slave_in;

      -- WB master - Bus IF ----------------------------------------
      master_o : out t_wishbone_master_out;
      master_i : in  t_wishbone_master_in
      --------------------------------------------------------------

      );
end eb_usb_slave_core;


architecture behavioral of eb_usb_slave_core is

  signal s_status_en  : std_logic;
  signal s_status_clr : std_logic;

  signal DEBUG_WB_master_o : t_wishbone_master_out;
  signal WB_master_i       : t_wishbone_master_in;


-- int eb if to cfg space
  signal eb_2_CFG_slave : t_wishbone_slave_in;
  signal CFG_2_eb_slave : t_wishbone_slave_out;


-- ext if to cfg space
  signal EXT_2_CFG_slave : t_wishbone_slave_in;
  signal CFG_2_EXT_slave : t_wishbone_slave_out;


  signal s_gather_2_eb_main_fsm : t_wishbone_master_out;
  signal s_eb_main_fsm_2_gather : t_wishbone_master_in;

--EB <-> RXCTRL
  signal s_scatter_2_eb_main_fsm : t_wishbone_slave_out;
  signal  s_eb_main_fsm_2_scatter : t_wishbone_slave_in;

  signal slim_src_o_dat : std_logic_vector(7 downto 0); 
  
  signal B_SEL_o : std_logic_vector(0 downto 0);


begin


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

-- convert streaming input from 16 to 32 bit data width
gather : WB_bus_adapter_streaming_sg generic map (g_adr_width_A => 32,
                                                 g_adr_width_B => 32,
                                                 g_dat_width_A => 8,
                                                 g_dat_width_B => 32,
                                                 g_pipeline    => 3)
    port map (clk_i     => clk_i,
              nRst_i    => nRst_i,
              A_CYC_i   => snk_i.cyc,
              A_STB_i   => snk_i.stb,
              A_ADR_i   => snk_i.adr,
              A_SEL_i   => snk_i.sel(0 downto 0),
              A_WE_i    => snk_i.we,
              A_DAT_i   => snk_i.dat(7 downto 0),
              A_ACK_o   => snk_o.ack,
              A_ERR_o   => snk_o.err,
              A_RTY_o   => snk_o.rty,
              A_STALL_o => snk_o.stall,
              A_DAT_o   => open,
              B_CYC_o   => s_gather_2_eb_main_fsm.CYC,
              B_STB_o   => s_gather_2_eb_main_fsm.STB,
              B_ADR_o   => s_gather_2_eb_main_fsm.ADR,
              B_SEL_o   => s_gather_2_eb_main_fsm.SEL,
              B_WE_o    => s_gather_2_eb_main_fsm.WE,
              B_DAT_o   => s_gather_2_eb_main_fsm.DAT,
              B_ACK_i   => s_eb_main_fsm_2_gather.ACK,
              B_ERR_i   => s_eb_main_fsm_2_gather.ERR,
              B_RTY_i   => s_eb_main_fsm_2_gather.RTY,
              B_STALL_i => s_eb_main_fsm_2_gather.STALL,
              B_DAT_i   => (others => '0')); 



src_o.dat <= x"000000" & slim_src_o_dat;



scatter: WB_bus_adapter_streaming_sg generic map (g_adr_width_A => 32,
                                                 g_adr_width_B => 32,
                                                 g_dat_width_A => 32,
                                                 g_dat_width_B => 8,
                                                 g_pipeline    =>  3)
                                      port map ( clk_i         => clk_i,
                                                 nRst_i        => nRst_i,
                                                 A_CYC_i       => s_eb_main_fsm_2_scatter.cyc,
                                                 A_STB_i       => s_eb_main_fsm_2_scatter.STB,
                                                 A_ADR_i       => s_eb_main_fsm_2_scatter.ADR,
                                                 A_SEL_i       => s_eb_main_fsm_2_scatter.SEL,
                                                 A_WE_i        => s_eb_main_fsm_2_scatter.WE,
                                                 A_DAT_i       => s_eb_main_fsm_2_scatter.DAT,
                                                 A_ACK_o       => s_scatter_2_eb_main_fsm.ack,
                                                 A_ERR_o       => s_scatter_2_eb_main_fsm.err,
                                                 A_RTY_o       => s_scatter_2_eb_main_fsm.rty,
                                                 A_STALL_o     => s_scatter_2_eb_main_fsm.stall,
                                                 A_DAT_o       => s_scatter_2_eb_main_fsm.dat,
                                                 B_CYC_o       => src_o.cyc,
                                                 B_STB_o       => src_o.stb,
                                                 B_ADR_o       => src_o.adr,
                                                 B_SEL_o       => B_SEL_o,
                                                 B_WE_o        => src_o.we,
                                                 B_DAT_o       => slim_src_o_dat,
                                                 B_ACK_i       => src_i.ack,
                                                 B_ERR_i       => src_i.err,
                                                 B_RTY_i       => src_i.rty,
                                                 B_STALL_i     => src_i.stall,
                                                 B_DAT_i       => (others => '0')); 


  src_o.sel <= "000" & B_SEL_o;
  
  EB : eb_main_fsm
    port map(
      --general
      clk_i  => clk_i,
      nRst_i => nRst_i,

      --Eth MAC WB Streaming signals
      EB_RX_i         => s_gather_2_eb_main_fsm,
      EB_RX_o         => s_eb_main_fsm_2_gather,

      EB_TX_i         => s_scatter_2_eb_main_fsm,
      EB_TX_o         => s_eb_main_fsm_2_scatter,
      TX_silent_o     => open,
      byte_count_rx_i => (others => '0'),

      config_master_i => CFG_2_eb_slave,
      config_master_o => eb_2_CFG_slave,

      --WB IC signals
      WB_master_i => WB_master_i,
      WB_master_o => DEBUG_WB_master_o
      );  


  s_status_en  <= WB_master_i.ACK or WB_master_i.ERR;
  s_status_clr <= not DEBUG_WB_master_o.CYC;

  cfg_space : eb_config
    generic map(
      g_sdb_address => g_sdb_address)
    port map(
      --general
      clk_i  => clk_i,
      nRst_i => nRst_i,

      status_i   => WB_master_i.ERR,
      status_en  => s_status_en,
      status_clr => s_status_clr,

      my_mac_o  => open,
      my_ip_o   => open,
      my_port_o => open,

      local_slave_o => CFG_2_EXT_slave,
      local_slave_i => EXT_2_CFG_slave,

      eb_slave_o => CFG_2_eb_slave,
      eb_slave_i => eb_2_CFG_slave
      );

end behavioral;
