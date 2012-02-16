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

port
(
	clk_i           	: in    std_logic;   --! clock input
	nRst_i				: in 	std_logic;
	
	-- EB streaming sink ------------------------------------
	snk_i		: in 	t_wrf_sink_in;						--
	snk_o		: out	t_wrf_sink_out;						--
	--------------------------------------------------------------
	
	-- EB streaming sourc ------------------------------------
	src_o		: out t_wrf_source_out;						--
	src_i		: in  t_wrf_source_in;						--
	--------------------------------------------------------------

 	-- WB master IF ----------------------------------------------
	master_o : out t_wishbone_master_out;
   master_i : in  t_wishbone_master_in;
	--------------------------------------------------------------
	
	-- slave Cfg IF ----------------------------------------------
	cfg_slave_cyc_i   : in  std_logic                     := '0';
	cfg_slave_we_i    : in  std_logic                     := '0';
	cfg_slave_stb_i   : in  std_logic                     := '0';
	cfg_slave_sel_i   : in  std_logic_vector(3 downto 0)  := "0000";
	cfg_slave_adr_i   : in  std_logic_vector(31 downto 0) := x"00000000";
	cfg_slave_dat_i   : in  std_logic_vector(31 downto 0) := x"00000000";
	cfg_slave_dat_o   : out std_logic_vector(31 downto 0);
	cfg_slave_stall_o : out std_logic;
	cfg_slave_ack_o   : out std_logic;
	cfg_slave_err_o   : out std_logic
	
);
end component;

begin

  EB_CORE_1 : EB_CORE
    generic map (
      g_master_slave => "SLAVE")
    port map (
      clk_i          => clk_sys_i,
      nRst_i         => rst_n_i,
      snk_i      		=> snk_i,
		snk_o      		=> snk_o,
      src_o      		=> src_o,
		src_i      		=> src_i,
      master_o 		=> master_o,
      master_i   		=> master_i
      );
  
end wrapper;
