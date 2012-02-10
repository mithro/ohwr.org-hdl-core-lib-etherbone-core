library ieee;
use ieee.std_logic_1164.all;

use work.Wishbone_pkg.all;
use work.wr_fabric_pkg.all;

entity xetherbone_core is
  
  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    snk_i : in  t_wrf_sink_in;
    snk_o : out t_wrf_sink_out;

    src_i : in  t_wrf_source_in;
    src_o : out t_wrf_source_out;
    
    master_i : in  t_wishbone_master_in;
    master_o : out t_wishbone_master_out
    );

end xetherbone_core;


architecture wrapper of xetherbone_core is

  component EB_CORE
    generic (
      g_master_slave : string := "SLAVE");
    port (
      clk_i             : in  std_logic;
      nRst_i            : in  std_logic;
      snk_CYC_i         : in  std_logic;
      snk_STB_i         : in  std_logic;
      snk_DAT_i         : in  std_logic_vector(15 downto 0);
      snk_sel_i         : in  std_logic_vector(1 downto 0);
      snk_adr_i         : in  std_logic_vector(1 downto 0);
      snk_WE_i          : in  std_logic;
      snk_STALL_o       : out std_logic;
      snk_ERR_o         : out std_logic;
      snk_ACK_o         : out std_logic;
      src_CYC_o         : out std_logic;
      src_STB_o         : out std_logic;
      src_WE_o          : out std_logic;
      src_DAT_o         : out std_logic_vector(15 downto 0);
      src_STALL_i       : in  std_logic;
      src_ERR_i         : in  std_logic;
      src_ACK_i         : in  std_logic;
      src_adr_o         : out std_logic_vector(1 downto 0);
      src_sel_o         : out std_logic_vector(1 downto 0);
      debug_TX_TOL_o    : out std_logic_vector(15 downto 0);
      hex_switch_i      : in  std_logic_vector(3 downto 0)  := x"0";
      cfg_slave_cyc_i   : in  std_logic                     := '0';
      cfg_slave_we_i    : in  std_logic                     := '0';
      cfg_slave_stb_i   : in  std_logic                     := '0';
      cfg_slave_sel_i   : in  std_logic_vector(3 downto 0)  := "0000";
      cfg_slave_adr_i   : in  std_logic_vector(31 downto 0) := x"00000000";
      cfg_slave_dat_i   : in  std_logic_vector(31 downto 0) := x"00000000";
      cfg_slave_dat_o   : out std_logic_vector(31 downto 0);
      cfg_slave_stall_o : out std_logic;
      cfg_slave_ack_o   : out std_logic;
      cfg_slave_err_o   : out std_logic;
      master_cyc_o      : out std_logic;
      master_we_o       : out std_logic;
      master_stb_o      : out std_logic;
      master_sel_o      : out std_logic_vector(3 downto 0);
      master_adr_o      : out std_logic_vector(31 downto 0);
      master_dat_o      : out std_logic_vector(31 downto 0);
      master_dat_i      : in  std_logic_vector(31 downto 0);
      master_stall_i    : in  std_logic;
      master_ack_i      : in  std_logic);
  end component;

begin

  EB_CORE_1 : EB_CORE
    generic map (
      g_master_slave => "SLAVE")
    port map (
      clk_i          => clk_sys_i,
      nRst_i         => rst_n_i,
      snk_CYC_i      => snk_i.CYC,
      snk_STB_i      => snk_i.STB,
      snk_DAT_i      => snk_i.DAT,
      snk_sel_i      => snk_i.sel,
      snk_adr_i      => snk_i.adr,
      snk_WE_i       => snk_i.WE,
      snk_STALL_o    => snk_o.STALL,
      snk_ERR_o      => snk_o.ERR,
      snk_ACK_o      => snk_o.ACK,
      src_CYC_o      => src_o.CYC,
      src_STB_o      => src_o.STB,
      src_WE_o       => src_o.WE,
      src_DAT_o      => src_o.DAT,
      src_STALL_i    => src_i.STALL,
      src_ERR_i      => '0',
      src_ACK_i      => src_i.ACK,
      src_adr_o      => src_o.adr,
      src_sel_o      => src_o.sel,
      master_cyc_o   => master_o.cyc,
      master_we_o    => master_o.we,
      master_stb_o   => master_o.stb,
      master_sel_o   => master_o.sel,
      master_adr_o   => master_o.adr,
      master_dat_o   => master_o.dat,
      master_dat_i   => master_i.dat,
      master_ack_i   => master_i.ack,
      master_stall_i => master_i.stall);
  
end wrapper;
