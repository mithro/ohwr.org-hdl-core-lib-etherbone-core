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

signal dummy_slave_in : t_wishbone_slave_in;


  component eb_slave_core
  port
(
	clk_i           	: in    std_logic;   --! clock input
	nRst_i				: in 	std_logic;
	
	-- EB streaming sink -----------------------------------------
	snk_i		: in 	t_wrf_sink_in;						
	snk_o		: out	t_wrf_sink_out;						
	--------------------------------------------------------------
	
	-- EB streaming source ---------------------------------------
	src_o		: out t_wrf_source_out;					
	src_i		: in  t_wrf_source_in;						
	--------------------------------------------------------------

   -- WB slave - Cfg IF -----------------------------------------
	cfg_slave_o : out t_wishbone_slave_out;
   cfg_slave_i : in  t_wishbone_slave_in;
	
 	-- WB master - Bus IF ----------------------------------------
	master_o : out t_wishbone_master_out;
   master_i : in  t_wishbone_master_in
	--------------------------------------------------------------
);	
end component;

begin

  EB_CORE_1 : eb_slave_core
    port map (
      clk_i          => clk_sys_i,
      nRst_i         => rst_n_i,
      snk_i      		=> snk_i,
		snk_o      		=> snk_o,
      src_o      		=> src_o,
		src_i      		=> src_i,
		cfg_slave_o		=> open,
		cfg_slave_i		=> dummy_slave_in,
      master_o 		=> master_o,
      master_i   		=> master_i
      );

	 
		
end wrapper;
