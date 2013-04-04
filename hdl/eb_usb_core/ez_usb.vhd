------------------------------------------------------------------------------
-- Title      : EZ-USB Etherbone+Console bridge
-- Project    : Etherbone Core
------------------------------------------------------------------------------
-- File       : xwb_ez_usb.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-04-04
-- Last update: 2013-04-04
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: A simple Wishbone mux that drives the off-chip EZ-USB FIFOs
--  This module
-------------------------------------------------------------------------------
-- Copyright (c) 2010 GSI
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-04-04  1.0      terpstra        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.ez_usb_pkg.all;
use work.etherbone_pkg.all;

entity ez_usb is
  generic(
    g_sdb_address  : t_wishbone_address;
    g_clock_period : integer := 16; -- clk_sys_i in ns
    g_board_delay  : integer := 2;  -- path length from FPGA to chip
    g_margin       : integer := 4  -- too lazy to consider FPGA timing constraints? increase this.
    );
  port(
    clk_sys_i : in  std_logic;
    rstn_i    : in  std_logic;

    -- Wishbone interface
    master_i  : in  t_wishbone_master_in;
    master_o  : out t_wishbone_master_out;
    
    -- USB Console
    uart_o    : out std_logic;
    uart_i    : in  std_logic;

    -- External signals
    fifoadr_o : out std_logic_vector(1 downto 0);
    flagbn_i  : in  std_logic;
    flagcn_i  : in  std_logic;
    sloen_o   : out std_logic;
    slrdn_o   : out std_logic;
    slwrn_o   : out std_logic;
    pktendn_o : out std_logic;
    fd_i      : in  std_logic_vector(7 downto 0);
    fd_o      : out std_logic_vector(7 downto 0);
    fd_oen_o  : out std_logic);
end ez_usb;

architecture rtl of ez_usb is
 
  component uart_baud_gen
    generic (
      g_baud_acc_width : integer);
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      baudrate_i   : in  std_logic_vector(g_baud_acc_width downto 0);
      baud_tick_o  : out std_logic;
      baud8_tick_o : out std_logic);
  end component;

  component uart_async_rx
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      baud8_tick_i : in  std_logic;
      rxd_i        : in  std_logic;
      rx_ready_o   : out std_logic;
      rx_error_o   : out std_logic;
      rx_data_o    : out std_logic_vector(7 downto 0));
  end component;

  component uart_async_tx
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      baud_tick_i  : in  std_logic;
      txd_o        : out std_logic;
      tx_start_p_i : in  std_logic;
      tx_data_i    : in  std_logic_vector(7 downto 0);
      tx_busy_o    : out std_logic);
  end component;

  signal rx_ready   : std_logic;
  signal baud_tick  : std_logic;
  signal baud8_tick : std_logic;
  
  signal uart2usb_uart_i : t_wishbone_slave_in;
  signal uart2usb_uart_o : t_wishbone_slave_out;
  signal uart2usb_usb_i  : t_wishbone_slave_in;
  signal uart2usb_usb_o  : t_wishbone_slave_out;
  signal usb2uart_usb_i  : t_wishbone_slave_in;
  signal usb2uart_usb_o  : t_wishbone_slave_out;
  signal usb2uart_uart_i : t_wishbone_slave_in;
  signal usb2uart_uart_o : t_wishbone_slave_out;
  
  signal eb2usb_m     : t_wishbone_slave_in;
  signal eb2usb_s     : t_wishbone_slave_out;
  signal usb2eb_usb_i : t_wishbone_slave_in;
  signal usb2eb_usb_o : t_wishbone_slave_out;
  signal usb2eb_eb_i  : t_wishbone_slave_in;
  signal usb2eb_eb_o  : t_wishbone_slave_out;
  

begin

  EZUSB : ez_usb_fifos
    generic map(
      g_clock_period => g_clock_period,
      g_board_delay  => g_board_delay,
      g_margin       => g_margin,
      g_fifo_width   => 8,
      g_num_fifos    => 4)
    port map(
      clk_sys_i    => clk_sys_i,
      rstn_i       => rstn_i,
      
      slave_i(0)   => usb2eb_usb_i, -- EP2 (out) = host writes to EB
      slave_o(0)   => usb2eb_usb_o,
      slave_i(2)   => eb2usb_m,     -- EP6 (in)  = EB writes to host
      slave_o(2)   => eb2usb_s,
      
      slave_i(1)   => usb2uart_usb_i, -- EP4 (out) = host writes to uart
      slave_o(1)   => usb2uart_usb_o,
      slave_i(3)   => uart2usb_usb_i, -- EP8 (in)  = uart writes to host
      slave_o(3)   => uart2usb_usb_o,
      
      fifoadr_o    => fifoadr_o,
      flagbn_i     => flagbn_i,
      flagcn_i     => flagcn_i,
      sloen_o      => sloen_o,
      slrdn_o      => slrdn_o,
      slwrn_o      => slwrn_o,
      pktendn_o    => pktendn_o,
      fd_i         => fd_i,
      fd_o         => fd_o,
      fd_oen_o     => fd_oen_o);
  
  -- Both USB and UART are slaves
  UART2USB : xwb_streamer
    generic map(
      logRingLen => 8) -- allow up to 256 bytes in buffer
    port map(
      clk_i      => clk_sys_i,
      rst_n_i    => rstn_i,
      r_master_o => uart2usb_uart_i,
      r_master_i => uart2usb_uart_o,
      w_master_o => uart2usb_usb_i,
      w_master_i => uart2usb_usb_o);
  
  USB2UART : xwb_streamer
    generic map(
      logRingLen => 8) -- allow up to 256 bytes in buffer
    port map(
      clk_i      => clk_sys_i,
      rst_n_i    => rstn_i,
      r_master_o => usb2uart_usb_i,
      r_master_i => usb2uart_usb_o,
      w_master_o => usb2uart_uart_i,
      w_master_i => usb2uart_uart_o);
  
  U_BAUD_GEN : uart_baud_gen
    generic map(
      g_baud_acc_width => 16)
    port map(
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rstn_i,
      baudrate_i   => "00000001111000110",
      baud_tick_o  => baud_tick,
      baud8_tick_o => baud8_tick);
  
  U_TX : uart_async_tx -- USB2UART
    port map(
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rstn_i,
      baud_tick_i  => baud_tick,
      txd_o        => uart_o,
      tx_start_p_i => usb2uart_uart_i.stb,
      tx_data_i    => usb2uart_uart_i.dat(7 downto 0),
      tx_busy_o    => usb2uart_uart_o.stall);
  usb2uart_uart_o.ack <= usb2uart_uart_i.stb and not usb2uart_uart_o.stall;
  usb2uart_uart_o.err <= '0';
  usb2uart_uart_o.rty <= '0';
  usb2uart_uart_o.dat <= (others => '0');
  usb2uart_uart_o.int <= '0';
  
  U_RX : uart_async_rx -- UART2USB
    port map(
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rstn_i,
      baud8_tick_i => baud8_tick,
      rxd_i        => uart_i,
      rx_ready_o   => rx_ready,
      rx_error_o   => open,
      rx_data_o    => uart2usb_uart_o.dat(7 downto 0));
  uart2usb_uart_o.ack <= rx_ready and uart2usb_uart_i.cyc and uart2usb_uart_i.stb;
  uart2usb_uart_o.err <= '0';
  uart2usb_uart_o.rty <= '0';
  uart2usb_uart_o.int <= '0';
  uart2usb_uart_o.dat(31 downto 8) <= (others => '0');
  uart2usb_uart_o.stall <= not rx_ready;
  
  -- Both EB input and USB output are slaves
  USB2EB : xwb_streamer
    generic map(
      logRingLen => 8) -- allow up to 256 bytes in buffer
    port map(
      clk_i      => clk_sys_i,
      rst_n_i    => rstn_i,
      r_master_o => usb2eb_usb_i,
      r_master_i => usb2eb_usb_o,
      w_master_o => usb2eb_eb_i,
      w_master_i => usb2eb_eb_o);
  
  master_o <= cc_dummy_slave_in;
--  EB : eb_usb_slave_core
--    generic map(
--      g_sdb_address => x"00000000" & g_sdb_address)
--    port map(
--      clk_i       => clk_sys_i,
--      nRst_i      => rstn_i,
--      snk_i       => usb2eb_eb_i,
--      snk_o       => usb2eb_eb_o,
--      src_o       => eb2usb_m,
--      src_i       => eb2usb_s,
--      cfg_slave_o => open,
--      cfg_slave_i => cc_dummy_slave_in,
--      master_o    => master_o,
--      master_i    => master_i);
  

end rtl;
