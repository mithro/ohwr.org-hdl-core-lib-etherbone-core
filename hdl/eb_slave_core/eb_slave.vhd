------------------------------------------------------------------------------
-- Title      : Etherbone Slave
-- Project    : Etherbone Core
------------------------------------------------------------------------------
-- File       : eb_slave.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-04-08
-- Last update: 2013-04-08
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Connect all the components of an Etherbone slave
-------------------------------------------------------------------------------
-- Copyright (c) 2013 GSI
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-04-08  1.0      terpstra        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_internals_pkg.all;

entity eb_slave is
  generic(
    g_sdb_address : t_wishbone_address);
  port(
    clk_i       : in std_logic;  --! System Clk
    nRst_i      : in std_logic;  --! active low sync reset

    EB_RX_i     : in  t_wishbone_slave_in;   --! Streaming wishbone(record) sink from RX transport protocol block
    EB_RX_o     : out t_wishbone_slave_out;  --! Streaming WB sink flow control to RX transport protocol block
    EB_TX_i     : in  t_wishbone_master_in;  --! Streaming WB src flow control from TX transport protocol block
    EB_TX_o     : out t_wishbone_master_out; --! Streaming WB src to TX transport protocol block

    WB_config_i : in  t_wishbone_slave_in;    --! WB V4 interface to WB interconnect/device(s)
    WB_config_o : out t_wishbone_slave_out;   --! WB V4 interface to WB interconnect/device(s)
    WB_master_i : in  t_wishbone_master_in;   --! WB V4 interface to WB interconnect/device(s)
    WB_master_o : out t_wishbone_master_out); --! WB V4 interface to WB interconnect/device(s)
end eb_slave;

architecture rtl of eb_slave is
  signal rstn_i : std_logic;
  
  signal mux_empty      : std_logic;
  signal errreg         : std_logic_vector(63 downto 0);
  signal wbm_busy       : std_logic;
  signal rx_stall       : std_logic;
  signal tx_cyc         : std_logic;
  
  signal fsm_tag_stb    : std_logic;
  signal fsm_tag_dat    : std_logic_vector(1 downto 0);
  signal tag_fsm_full   : std_logic;
  signal fsm_pass_stb   : std_logic;
  signal fsm_pass_dat   : std_logic_vector(31 downto 0);
  signal pass_fsm_full  : std_logic;
  signal fsm_cfg_wb     : t_wishbone_master_out;
  signal cfg_fsm_full   : std_logic;
  signal fsm_wbm_wb     : t_wishbone_master_out;
  signal wbm_fsm_full   : std_logic;
  
  signal mux_tag_pop    : std_logic;
  signal tag_mux_dat    : std_logic_vector(1 downto 0);
  signal tag_mux_empty  : std_logic;
  signal mux_pass_pop   : std_logic;
  signal pass_mux_dat   : std_logic_vector(31 downto 0);
  signal pass_mux_empty : std_logic;
  signal mux_cfg_pop    : std_logic;
  signal cfg_mux_dat    : std_logic_vector(31 downto 0);
  signal cfg_mux_empty  : std_logic;
  signal mux_wbm_pop    : std_logic;
  signal wbm_mux_dat    : std_logic_vector(31 downto 0);
  signal wbm_mux_empty  : std_logic;
  
begin

  rstn_i <= nRst_i;
  
  EB_RX_o.ack <= EB_RX_i.cyc and EB_RX_i.stb and not rx_stall;
  EB_RX_o.err <= '0';
  EB_RX_o.rty <= '0';
  EB_RX_o.int <= '0';
  EB_RX_o.stall <= rx_stall;
  
  fsm : eb_rx_fsm 
    port map(
      clk_i       => clk_i,
      rstn_i      => rstn_i,
      rx_cyc_i    => EB_RX_i.cyc,
      rx_stb_i    => EB_RX_i.stb,
      rx_dat_i    => EB_RX_i.dat,
      rx_stall_o  => rx_stall,
      tx_cyc_o    => tx_cyc,
      mux_empty_i => mux_empty,
      tag_stb_o   => fsm_tag_stb,
      tag_dat_o   => fsm_tag_dat,
      tag_full_i  => tag_fsm_full,
      pass_stb_o  => fsm_pass_stb,
      pass_dat_o  => fsm_pass_dat,
      pass_full_i => pass_fsm_full,
      cfg_wb_o    => fsm_cfg_wb,
      cfg_full_i  => cfg_fsm_full,
      wbm_wb_o    => fsm_wbm_wb,
      wbm_full_i  => wbm_fsm_full);

  EB_TX_o.cyc <= tx_cyc;
  EB_TX_o.we  <= '1';
  EB_TX_o.sel <= (others => '1');
  EB_TX_o.adr <= (others => '0');
  
  mux : eb_tx_mux
    port map (
      clk_i        => clk_i,
      rstn_i       => rstn_i,
      tag_pop_o    => mux_tag_pop,
      tag_dat_i    => tag_mux_dat,
      tag_empty_i  => tag_mux_empty,
      pass_pop_o   => mux_pass_pop,
      pass_dat_i   => pass_mux_dat,
      pass_empty_i => pass_mux_empty,
      cfg_pop_o    => mux_cfg_pop,
      cfg_dat_i    => cfg_mux_dat,
      cfg_empty_i  => cfg_mux_empty,
      wbm_pop_o    => mux_wbm_pop,
      wbm_dat_i    => wbm_mux_dat,
      wbm_empty_i  => wbm_mux_empty,
      tx_stb_o     => EB_TX_o.stb,
      tx_dat_o     => EB_TX_o.dat,
      tx_stall_i   => EB_TX_i.stall);

  tag : eb_tag_fifo
    port map(
      clk_i       => clk_i,
      rstn_i      => rstn_i,
      fsm_stb_i   => fsm_tag_stb,
      fsm_dat_i   => fsm_tag_dat,
      fsm_full_o  => tag_fsm_full,
      mux_pop_i   => mux_tag_pop,
      mux_dat_o   => tag_mux_dat,
      mux_empty_o => tag_mux_empty);

  pass : eb_pass_fifo
    port map(
      clk_i       => clk_i,
      rstn_i      => rstn_i,
      fsm_stb_i   => fsm_pass_stb,
      fsm_dat_i   => fsm_pass_dat,
      fsm_full_o  => pass_fsm_full,
      mux_pop_i   => mux_pass_pop,
      mux_dat_o   => pass_mux_dat,
      mux_empty_o => pass_mux_empty);

  cfg : eb_cfg_fifo
    generic map(
      g_sdb_address => g_sdb_address)
    port map(
      clk_i       => clk_i,
      rstn_i      => rstn_i,
      errreg_i    => errreg,
      cfg_i       => WB_config_i,
      cfg_o       => WB_config_o,
      fsm_wb_i    => fsm_cfg_wb,
      fsm_full_o  => cfg_fsm_full,
      mux_pop_i   => mux_cfg_pop,
      mux_dat_o   => cfg_mux_dat,
      mux_empty_o => cfg_mux_empty);

  WB_master_o.cyc <= fsm_wbm_wb.cyc;
  wbm : eb_wbm_fifo
    port map(
      clk_i       => clk_i,
      rstn_i      => rstn_i,
      errreg_o    => errreg,
      busy_o      => wbm_busy,
      wb_stb_o    => WB_master_o.stb,
      wb_adr_o    => WB_master_o.adr,
      wb_sel_o    => WB_master_o.sel,
      wb_we_o     => WB_master_o.we,
      wb_dat_o    => WB_master_o.dat,
      wb_i        => WB_master_i,
      fsm_wb_i    => fsm_wbm_wb,
      fsm_full_o  => wbm_fsm_full,
      mux_pop_i   => mux_wbm_pop,
      mux_dat_o   => wbm_mux_dat,
      mux_empty_o => wbm_mux_empty);

  mux_empty <= 
    not wbm_busy   and 
--    wbm_mux_empty  and -- redundant
--    cfg_mux_empty  and 
--    pass_mux_empty and
    tag_mux_empty;

end rtl;
