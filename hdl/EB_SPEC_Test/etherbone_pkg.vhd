library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package etherbone_pkg is
  component EB_CORE is 
    generic(g_master_slave : STRING := "SLAVE");
    port(
      clk_i       : in  std_logic;
      nRst_i      : in  std_logic;
      snk_i       : in  t_wrf_sink_in;
      snk_o       : out t_wrf_sink_out;
      src_o       : out t_wrf_source_out;
      src_i       : in  t_wrf_source_in;
      cfg_slave_o : out t_wishbone_slave_out;
      cfg_slave_i : in  t_wishbone_slave_in;
      master_o    : out t_wishbone_master_out;
      master_i    : in  t_wishbone_master_in);
end etherbone_pkg;
