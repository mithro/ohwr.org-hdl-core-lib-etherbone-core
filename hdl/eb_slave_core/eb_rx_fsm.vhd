library IEEE;
--! Standard packages
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages
use work.eb_internals_pkg.all;
use work.wishbone_pkg.all;


entity eb_rx_fsm is
  port (
    clk_i         : in  std_logic;
    rstn_i        : in  std_logic;
    
    rx_cyc_i      : in  std_logic;
    rx_stb_i      : in  std_logic;
    rx_dat_i      : in  std_logic_vector(31 downto 0);
    rx_stall_o    : out std_logic;
    
    mux_empty_i   : in  std_logic;
    
    tag_stb_o     : out std_logic;
    tag_dat_o     : out t_tag;
    tag_stall_i   : in  std_logic;
    
    pass_stb_o    : out std_logic;
    pass_dat_o    : out std_logic_vector(31 downto 0); 
    pass_stall_i  : in  std_logic;
    
    cfg_o         : out t_wishbone_master_out;  -- cyc always hi
    cfg_stall_i   : in  std_logic;
    
    wb_o          : out t_wishbone_master_out;
    wb_stall_i    : in  std_logic );
end entity;

architecture behavioral of eb_rx_fsm is

signal 



begin




end architecture;



