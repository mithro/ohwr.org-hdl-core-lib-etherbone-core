------------------------------------------------------------------------------
-- Title      : Etherbone Wishbone Master FIFO
-- Project    : Etherbone Core
------------------------------------------------------------------------------
-- File       : eb_wbm_fifo.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-04-08
-- Last update: 2013-04-08
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Buffers Wishbone requests to resulting data
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

entity eb_wbm_fifo is
  port(
    clk_i       : in  std_logic;
    rstn_i      : in  std_logic;
    
    errreg_o    : out std_logic_vector(63 downto 0);
    busy_o      : out std_logic;
    
    wb_stb_o    : out std_logic;
    wb_adr_o    : out t_wishbone_address;
    wb_sel_o    : out t_wishbone_byte_select;
    wb_we_o     : out std_logic;
    wb_dat_o    : out t_wishbone_data;
    wb_i        : in  t_wishbone_master_in;
    
    fsm_wb_i    : in  t_wishbone_master_out;
    fsm_full_o  : out std_logic;

    mux_pop_i   : in  std_logic;
    mux_dat_o   : out std_logic_vector(31 downto 0);
    mux_empty_o : out std_logic);
end eb_wbm_fifo;

architecture rtl of eb_pass_fifo is
  
  constant c_size  : natural := 256;
  constant c_depth : natural := f_ceil_log2(c_size);
  
  signal r_timeout  : unsigned(20 downto 0);
  signal r_inflight : unsigned(c_depth-1 downto 0);
  signal r_full     : std_logic;
  signal r_errreg   : std_logic_vector(63 downto 0);
  signal s_wb_i_rdy : std_logic;
  signal s_mux_dat  : std_logic_vector(31 downto 0);
  signal s_mux_we   : std_logic;
  
begin

  wb_stb_o <= fsm_wb_i.stb;
  wb_adr_o <= fsm_wb_i.adr;
  wb_sel_o <= fsm_wb_i.sel;
  wb_we_o  <= fsm_wb_i.we;
  wb_dat_o <= fsm_wb_i.dat;
  fsm_full_o <= r_full;
  
  s_wb_i_rdy <= wb_i.ack or wb_i.err or wb_i.rty;
  
  full : process(rstn_i, clk_i) is
  begin
    if rstn_i = '0' then
      r_full <= '0';
    elsif rising_edge(clk_i) then
      if r_inflight < size-2 then
        r_full <= '0';
      else
        r_full <= '1';
      end if;
    end if;
  end process;
  
  inflight : process(rstn_i, clk_i) is
  begin
    if rstn_i = '0' then
      r_inflight <= (others => '0');
      busy_o     <= '0';
    elsif rising_edge(clk_i) then
      if fsm_wb_i.stb = '1' then
        busy_o <= '1';
        if mux_pop_i = '1' then
          r_inflight <= r_inflight;
        else
          r_inflight <= r_inflight + 1;
        end if;
      else
        if r_inflight = 0 then
          busy_o <= '0';
        end if;
        
        if mux_pop_i = '1' then
          r_inflight <= r_inflight - 1;
        else
          r_inflight <= r_inflight;
        end if;
      end if;
    end if;
  end process;
  
  errreg : process(rstn_i, clk_i) is
  begin
    if rstn_i = '0' then
      r_errreg <= (others => '0');
    elsif rising_edge(clk_i) then
      if s_wb_i_rdy = '1' then
        r_errreg <= r_errreg(r_errreg'left-1 downto 0) & (not wb_i.ack);
      end if;
    end if;
  end process;
  
  datfifo : eb_fifo
    generic map(
      g_data_width => 32,
      g_size       => c_size)
    port map(
      clk_i     => clk_i,
      rs_n_i    => rstn_i,
      w_full_o  => open,
      w_push_i  => s_wb_i_rdy,
      w_dat_i   => wb_i.dat,
      r_empty_o => mux_empty_o,
      r_pop_i   => mux_pop_i,
      r_dat_o   => s_mux_dat);

  reqfifo : eb_fifo
    generic map(
      g_data_width => 1,
      g_size       => c_size)
    port map(
      clk_i     => clk_i,
      rs_n_i    => rstn_i,
      w_full_o  => open,
      w_push_i  => fsm_wb_i.stb,
      w_dat_i   => fsm_wb_i.we,
      r_empty_o => open,
      r_pop_i   => mux_pop_i,
      r_dat_o   => s_mux_we);
  
  mux_dat_o <= s_mux_dat when s_mux_we='0' else (others => '0');
  
end rtl;
