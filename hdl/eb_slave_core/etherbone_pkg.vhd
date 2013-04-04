library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;

package etherbone_pkg is
  constant c_etherbone_sdb : t_sdb_device := (
    abi_class     => x"0000", -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"01",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"4", --32-bit port granularity
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000ff",
    product => (
    vendor_id     => x"0000000000000651", -- GSI
    device_id     => x"68202b22",
    version       => x"00000001",
    date          => x"20130211",
    name          => "Etherbone-Config   ")));
  
component eb_usb_slave_core is
  generic(g_sdb_address : std_logic_vector(63 downto 0) := x"01234567ABCDEF00");
  port
    (
      clk_i  : in std_logic;            --! clock input
      nRst_i : in std_logic;

      -- EB streaming sink -----------------------------------------
      snk_i : in  t_wishbone_slave_in;
      snk_o : out t_wishbone_slave_out;
      --------------------------------------------------------------

      -- EB streaming source ---------------------------------------
      src_o : out t_wishbone_master_out;
      src_i : in  t_wishbone_master_in;
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

  component eb_slave_core is
    generic(g_sdb_address : std_logic_vector(63 downto 0)); 
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
  end component;

component WB_bus_adapter_streaming_sg
    generic(g_adr_width_A : natural := 32; g_adr_width_B : natural := 32;
    g_dat_width_A         : natural := 32; g_dat_width_B : natural := 16;
    g_pipeline            : natural
            );
    port(
      clk_i     : in  std_logic;
      nRst_i    : in  std_logic;
      A_CYC_i   : in  std_logic;
      A_STB_i   : in  std_logic;
      A_ADR_i   : in  std_logic_vector(g_adr_width_A-1 downto 0);
      A_SEL_i   : in  std_logic_vector(g_dat_width_A/8-1 downto 0);
      A_WE_i    : in  std_logic;
      A_DAT_i   : in  std_logic_vector(g_dat_width_A-1 downto 0);
      A_ACK_o   : out std_logic;
      A_ERR_o   : out std_logic;
      A_RTY_o   : out std_logic;
      A_STALL_o : out std_logic;
      A_DAT_o   : out std_logic_vector(g_dat_width_A-1 downto 0);
      B_CYC_o   : out std_logic;
      B_STB_o   : out std_logic;
      B_ADR_o   : out std_logic_vector(g_adr_width_B-1 downto 0);
      B_SEL_o   : out std_logic_vector(g_dat_width_B/8-1 downto 0);
      B_WE_o    : out std_logic;
      B_DAT_o   : out std_logic_vector(g_dat_width_B-1 downto 0);
      B_ACK_i   : in  std_logic;
      B_ERR_i   : in  std_logic;
      B_RTY_i   : in  std_logic;
      B_STALL_i : in  std_logic;
      B_DAT_i   : in  std_logic_vector(g_dat_width_B-1 downto 0)
      );
  end component;

  component sipo_flag is
    generic(g_width_IN : natural := 16; g_width_OUT : natural := 32);
    port(
      clk_i   : in  std_logic;
      nRst_i  : in  std_logic;
      d_i     : in  std_logic_vector(g_width_IN-1 downto 0);
      en_i    : in  std_logic;
      clr_i   : in  std_logic;
      q_o     : out std_logic_vector(g_width_OUT-1 downto 0);
      full_o  : out std_logic;
      empty_o : out std_logic
      );
  end component;



component piso_flag is
generic(g_width_IN : natural := 16; g_width_OUT  : natural := 32; g_protected : natural := 1); 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		d_i					: in std_logic_vector(g_width_IN-1 downto 0);
		en_i				: in std_logic;
		ld_i				: in std_logic;
		
		q_o					: out std_logic_vector(g_width_OUT-1 downto 0);
		full_o				: out std_logic;
		empty_o				: out std_logic
);
  end component;

component EB_checksum is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;
		
		en_i	: in std_logic; 
		data_i	: in std_logic_vector(15 downto 0);
		
		done_o	: out std_logic;
		sum_o	: out std_logic_vector(15 downto 0)
);
end component;

  component EB_TX_CTRL is
    port(
      clk_i  : in std_logic;
      nRst_i : in std_logic;

      --Eth MAC WB Streaming signals
      wb_slave_i : in  t_wishbone_slave_in;
      wb_slave_o : out t_wishbone_slave_out;


      src_i : in  t_wrf_source_in;
      src_o : out t_wrf_source_out;


      reply_MAC_i  : in std_logic_vector(6*8-1 downto 0);
      reply_IP_i   : in std_logic_vector(4*8-1 downto 0);
      reply_Port_i : in std_logic_vector(2*8-1 downto 0);


      TOL_i         : in std_logic_vector(2*8-1 downto 0);
      payload_len_i : in std_logic_vector(2*8-1 downto 0);

      my_mac_i  : in std_logic_vector(6*8-1 downto 0);
      my_vlan_i : in std_logic_vector(2*8-1 downto 0);
      my_ip_i   : in std_logic_vector(4*8-1 downto 0);
      my_port_i : in std_logic_vector(2*8-1 downto 0);


      silent_i : in std_logic;
      valid_i  : in std_logic

      );
  end component;

  component EB_RX_CTRL is
    port (
      clk_i  : in std_logic;
      nRst_i : in std_logic;

      -- Wishbone Fabric Interface I/O
      snk_i : in  t_wrf_sink_in;
      snk_o : out t_wrf_sink_out;

      --Eth MAC WB Streaming signals
      wb_master_i : in  t_wishbone_master_in;
      wb_master_o : out t_wishbone_master_out;

      reply_MAC_o   : out std_logic_vector(6*8-1 downto 0);
      reply_IP_o    : out std_logic_vector(4*8-1 downto 0);
      reply_Port_o  : out std_logic_vector(2*8-1 downto 0);
      TOL_o         : out std_logic_vector(2*8-1 downto 0);
      payload_len_o : out std_logic_vector(2*8-1 downto 0);

      my_mac_i  : in std_logic_vector(6*8-1 downto 0);
      my_vlan_i : in std_logic_vector(2*8-1 downto 0);
      my_ip_i   : in std_logic_vector(4*8-1 downto 0);
      my_port_i : in std_logic_vector(2*8-1 downto 0);

      valid_o : out std_logic

      );
  end component;

  component eb_main_fsm is
    port(
      clk_i  : in std_logic;
      nRst_i : in std_logic;

      --Eth MAC WB Streaming signals
      EB_RX_i : in  t_wishbone_slave_in;
      EB_RX_o : out t_wishbone_slave_out;

      EB_TX_i     : in  t_wishbone_master_in;
      EB_TX_o     : out t_wishbone_master_out;
      TX_silent_o : out std_logic;

      byte_count_rx_i : in std_logic_vector(15 downto 0);

      --config signals
      config_master_i : in  t_wishbone_master_in;  --! WB V4 interface to WB interconnect/device(s)
      config_master_o : out t_wishbone_master_out;  --! WB V4 interface to WB interconnect/device(s)


      --WB IC signals
      WB_master_i : in  t_wishbone_master_in;
      WB_master_o : out t_wishbone_master_out

      );
  end component;

  component eb_config is
    generic(
      g_sdb_address : std_logic_vector(63 downto 0));
    port(
      clk_i      : in std_logic;        --clock
      nRST_i     : in std_logic;
      status_i   : in std_logic;
      status_en  : in std_logic;
      status_clr : in std_logic;

      my_mac_o  : out std_logic_vector(6*8-1 downto 0);
      my_ip_o   : out std_logic_vector(4*8-1 downto 0);
      my_port_o : out std_logic_vector(2*8-1 downto 0);

      local_slave_o : out t_wishbone_slave_out;
      local_slave_i : in  t_wishbone_slave_in;  --! local Wishbone master lines

      eb_slave_o : out t_wishbone_slave_out;  --! EB Wishbone slave lines
      eb_slave_i : in  t_wishbone_slave_in
      );
  end component;

end etherbone_pkg;
