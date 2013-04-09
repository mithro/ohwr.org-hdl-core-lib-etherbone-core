------------------------------------------------------------------------------
-- Title      : Etherbone Register FIFO
-- Project    : Etherbone Core
------------------------------------------------------------------------------
-- File       : eb_fifo.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-04-08
-- Last update: 2013-04-08
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Converts streams of different widths
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
use work.genram_pkg.all;

-- r_dat_o is valid when r_empty_o=0
-- w_dat_i is valid when w_push_i =1
-- r_pop_i  affects r_empty_o on the next cycle
-- w_push_i affects w_full_o  on the next cycle
entity eb_fifo is
  generic(
    g_width_w : natural;
    g_width_r : natural);
  port(
    clk_i     : in  std_logic;
    rstn_i    : in  std_logic;
    w_full_o  : out std_logic;
    w_push_i  : in  std_logic;
    w_dat_i   : in  std_logic_vector(g_width_w-1 downto 0);
    r_empty_o : out std_logic;
    r_pop_i   : in  std_logic;
    r_dat_o   : out std_logic_vector(g_width_r-1 downto 0));
end eb_fifo;

architecture rtl of eb_fifo is
  function gcd(a, b : natural) return natural is
  begin
    if a > b then
      return gcd(b,a);
    elsif a = 0 then
      return b;
    else
      return gcd(b mod a, a);
    end if;
  end gcd;
  function max(a, b : natural) return natural is
  begin
    if b > a then
      return b;
    else
      return a;
    end if;
  end max;
  
  constant c_width   : natural := gcd(g_width_w, g_width_r);
  constant c_width_w : natural := g_width_w/c_width;
  constant c_width_r : natural := g_width_r/c_width;
  
  -- Must be large enough to fit two of the largest element to enable streaming
  constant c_depth : natural := f_ceil_log2(max(c_width_w, c_width_r) * 2);
  constant c_size  : natural := 2**c_depth;
  
  signal r_idx  : unsigned(c_depth downto 0);
  signal w_idx  : unsigned(c_depth downto 0);
  signal buf    : std_logic_vector(c_size*c_width-1 downto 0);
  
begin

  main : process(rstn_i, clk_i) is
    variable r_idx_next : unsigned(c_depth downto 0);
    variable w_idx_next : unsigned(c_depth downto 0);
  begin
    if rstn_i = '0' then
      r_idx     <= (others => '0');
      w_idx     <= (others => '0');
      w_full_o  <= '0';
      r_empty_o <= '1';
    elsif rising_edge(clk_i) then
    
      -- High bits go in first => lowest address in FIFO
      if w_push_i = '1' then
        for i in 0 to c_width_w-1 loop
          buf((((to_integer(w_idx)+i) mod c_size)+1)*c_width-1 downto 
              (((to_integer(w_idx)+i) mod c_size)+0)*c_width-0) <=
            w_dat_i((c_width_w-i)*c_width-1 downto (c_width_w-i-1)*c_width);
        end loop;
      end if;
      
      for i in 0 to c_width_r-1 loop
        r_dat_o((c_width_r-i)*c_width-1 downto (c_width_r-i)*c_width) <=
          buf((((to_integer(r_idx)+i) mod c_size)+1)*c_width-1 downto 
              (((to_integer(r_idx)+i) mod c_size)+0)*c_width-0);
      end loop;
      
      -- Compute next pointer state
      if r_pop_i = '1' then
        r_idx_next := r_idx + c_width_r;
      else
        r_idx_next := r_idx;
      end if;
      
      if w_push_i = '1' then
        w_idx_next := w_idx + c_width_w;
      else
        w_idx_next := w_idx;
      end if;
    
      -- Compare the newest pointers
      if w_idx_next - r_idx_next < c_width_r then
        w_empty_o <= '1';
      else
        w_empty_o <= '0';
      end if;
      
      if r_idx_next + c_size - w_idx_next < c_width_w then
        w_full_o <= '1';
      else
        w_full_o <= '0';
      end if;
      
      r_idx <= r_idx_next;
      w_idx <= w_idx_next;
      
    end if;
  end process;

end rtl;
