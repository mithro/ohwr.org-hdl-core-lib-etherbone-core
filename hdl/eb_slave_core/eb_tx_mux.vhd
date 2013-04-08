------------------------------------------------------------------------------
-- Title      : Etherbone TX MUX
-- Project    : Etherbone Core
------------------------------------------------------------------------------
-- File       : eb_tux_mux.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-04-08
-- Last update: 2013-04-08
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Combines output streams into a packet
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

entity eb_tx_mux is
  port(
    clk_i       : in  std_logic;
    rstn_i      : in  std_logic;
    
    tag_pop_o   : out std_logic;
    tag_dat_i   : in  t_tag;
    tag_empty_i : in  std_logic;
    
    pass_pop_o   : out std_logic;
    pass_dat_i   : in  std_logic_vector(31 downto 0); 
    pass_empty_i : in  std_logic;
    
    cfg_pop_o    : out std_logic;
    cfg_dat_i    : in  std_logic_vector(31 downto 0);
    cfg_empty_i  : in  std_logic;
    
    wbm_pop_o    : out t_wishbone_master_out;
    wbm_dat_i    : in  std_logic_vector(31 downto 0);
    wbm_empty_i  : in  std_logic;
    
    tx_stb_o     : out std_logic;
    tx_dat_o     : out std_logic_vector(31 downto 0);
    tx_stall_i   : in  std_logic);
end eb_tx_mux;

architecture rtl of eb_tx_mux is

  signal r_tx_stb    : std_logic;
  signal s_can_tx    : std_logic;
  signal s_dat_empty : std_logic;
  signal s_dat_value : std_logic_vector(31 downto 0);
  signal s_tag_pop   : std_logic;
  signal r_tag_valid : std_logic;
  signal r_tag_value : t_tag;

begin

  -- We can write whenever TX is unstalled and/or not full
  s_can_tx <= not r_tx_stb or not tx_stall_i;
  
  tx_stb_o <= r_tx_stb;
  tx_out : process(rstn_i, clk_i) is
  begin
    if rstn_i = '0' then
      r_tx_stb <= '0';
      tx_dat_o <= '0';
    elsif rising_edge(clk_i) then
      -- Can we push the data?
      if s_can_tx then
        r_tx_stb <= not s_dat_empty and r_tag_valid;
        tx_dat_o <= s_dat_value;
      end if;
    end if;
  end process;
  
  -- Pop the queue we fed into TX
  pass_pop_o <= s_can_tx and r_tag_valid and not pass_empty_i and (r_tag_value = c_tag_pass_on);
  cfg_pop_o  <= s_can_tx and r_tag_valid and not cfg_empty_i  and (r_tag_value = c_tag_cfg_req);
  wbm_pop_o  <= s_can_tx and r_tag_valid and not wbm_empty_i  and (r_tag_value = c_tag_wbm_req);
  s_tag_pop  <= s_can_tx and r_tag_valid and not s_dat_empty;
  
  with r_tag_value select
  s_dat_empty <= 
    cfg_empty_i  when c_tag_cfg_req,
    pass_empty_i when c_tag_pass_on,
    wbm_empty_i  when others;

  with r_tag_value select
  s_dat_value <= 
    cfg_dat_i  when c_tag_cfg_req,
    pass_dat_i when c_tag_pass_on,
    wbm_dat_i  when others;
    
  -- Pop the tag FIFO if the register is empty/emptied
  tag_pop_o <= not tag_empty_i and (s_tag_pop or not r_tag_valid);
  tag_in : process(rstn_i, clk_i) is
  begin
    if rstn_i = '0' then
      r_tag_valid <= '0';
      r_tag_value <= c_tag_pass_on;
    elsif rising_edge(clk_i) then
      if s_tag_pop = '1' then
        r_tag_valid <= not tag_empty_i;
        r_tag_value <= tag_dat_i;
      end if;
    end if;
  end process;
  
end rtl;
