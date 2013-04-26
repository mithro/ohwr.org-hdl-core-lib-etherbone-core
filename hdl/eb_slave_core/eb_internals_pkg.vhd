library IEEE;
--! Standard packages
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
use work.wishbone_pkg.all;
use work.wr_fabric_pkg.all;

package eb_internals_pkg is 

  subtype t_tag is std_logic_vector(2 downto 0);

  constant c_tag_drop_tx : t_tag := "000";
  constant c_tag_pass_tx : t_tag := "010";
  constant c_tag_pass_on : t_tag := "011";
  constant c_tag_cfg_req : t_tag := "100";
  constant c_tag_cfg_ign : t_tag := "101";
  constant c_tag_wbm_req : t_tag := "110";
  constant c_tag_wbm_ign : t_tag := "111";
  
  constant c_queue_depth : natural := 32;

  component eb_slave is
    generic(
      g_sdb_address    : t_wishbone_address;
      g_timeout_cycles : natural);
    port(
      clk_i       : in std_logic;  --! System Clk
      nRst_i      : in std_logic;  --! active low sync reset

      EB_RX_i     : in  t_wishbone_slave_in;   --! Streaming wishbone(record) sink from RX transport protocol block
      EB_RX_o     : out t_wishbone_slave_out;  --! Streaming WB sink flow control to RX transport protocol block
      EB_TX_i     : in  t_wishbone_master_in;  --! Streaming WB src flow control from TX transport protocol block
      EB_TX_o     : out t_wishbone_master_out; --! Streaming WB src to TX transport protocol block

      WB_config_i : in  t_wishbone_slave_in;    --! WB V4 interface to WB interconnect/device(s)
      WB_config_o : out t_wishbone_slave_out;   --! WB V4 interface to WB interconnect/device(s)
      WB_master_i : in  t_wishbone_master_in;   --! WB V4 interface to WB interconnect/device(s)
      WB_master_o : out t_wishbone_master_out;  --! WB V4 interface to WB interconnect/device(s)
      
      my_mac_o    : out std_logic_vector(47 downto 0);
      my_ip_o     : out std_logic_vector(31 downto 0);
      my_port_o   : out std_logic_vector(15 downto 0));
  end component;

  component eb_rx_fsm is
    port(
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      
      rx_cyc_i    : in  std_logic;
      rx_stb_i    : in  std_logic;
      rx_dat_i    : in  t_wishbone_data;
      rx_stall_o  : out std_logic;
      
      tag_stb_o   : out std_logic;
      tag_dat_o   : out t_tag;
      tag_full_i  : in  std_logic;
      
      pass_stb_o  : out std_logic;
      pass_dat_o  : out t_wishbone_data;
      pass_full_i : in  std_logic;
      
      cfg_stb_o   : out std_logic;
      cfg_adr_o   : out t_wishbone_address;
      cfg_full_i  : in  std_logic;
      
      wbm_stb_o   : out std_logic;
      wbm_full_i  : in  std_logic;
      wbm_busy_i  : in  std_logic;
      
      master_o       : out t_wishbone_master_out;
      master_stall_i : in  std_logic);
  end component;

  component eb_fifo is
    generic(
      g_width : natural;
      g_size  : natural);
    port(
      clk_i     : in  std_logic;
      rstn_i    : in  std_logic;
      w_full_o  : out std_logic;
      w_push_i  : in  std_logic;
      w_dat_i   : in  std_logic_vector(g_width-1 downto 0);
      r_empty_o : out std_logic;
      r_pop_i   : in  std_logic;
      r_dat_o   : out std_logic_vector(g_width-1 downto 0));
  end component;

  component eb_tx_mux is
    port(
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      
      tag_pop_o   : out std_logic;
      tag_dat_i   : in  t_tag;
      tag_empty_i : in  std_logic;
      
      pass_pop_o   : out std_logic;
      pass_dat_i   : in  t_wishbone_data;
      pass_empty_i : in  std_logic;
      
      cfg_pop_o    : out std_logic;
      cfg_dat_i    : in  t_wishbone_data;
      cfg_empty_i  : in  std_logic;
      
      wbm_pop_o    : out std_logic;
      wbm_dat_i    : in  t_wishbone_data;
      wbm_empty_i  : in  std_logic;
      
      tx_cyc_o     : out std_logic;
      tx_stb_o     : out std_logic;
      tx_dat_o     : out t_wishbone_data;
      tx_stall_i   : in  std_logic);
  end component;

  component eb_tag_fifo is
    port(
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      
      fsm_stb_i   : in  std_logic;
      fsm_dat_i   : in  t_tag;
      fsm_full_o  : out std_logic;

      mux_pop_i   : in  std_logic;
      mux_dat_o   : out t_tag;
      mux_empty_o : out std_logic);
  end component;

  component eb_pass_fifo is
    port(
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      
      fsm_stb_i   : in  std_logic;
      fsm_dat_i   : in  t_wishbone_data;
      fsm_full_o  : out std_logic;

      mux_pop_i   : in  std_logic;
      mux_dat_o   : out t_wishbone_data;
      mux_empty_o : out std_logic);
  end component;

  component eb_cfg_fifo is
    generic(
      g_sdb_address : t_wishbone_address);
    port(
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      
      errreg_i    : in  std_logic_vector(63 downto 0);
      
      cfg_i       : in  t_wishbone_slave_in;
      cfg_o       : out t_wishbone_slave_out;
      
      fsm_stb_i   : in  std_logic;
      fsm_adr_i   : in  t_wishbone_address;
      fsm_full_o  : out std_logic;

      mux_pop_i   : in  std_logic;
      mux_dat_o   : out t_wishbone_data;
      mux_empty_o : out std_logic;
      
      my_mac_o    : out std_logic_vector(47 downto 0);
      my_ip_o     : out std_logic_vector(31 downto 0);
      my_port_o   : out std_logic_vector(15 downto 0));
  end component;

  component eb_wbm_fifo is
    generic(
      g_timeout_cycles : natural);
    port(
      clk_i       : in  std_logic;
      rstn_i      : in  std_logic;
      
      errreg_o    : out std_logic_vector(63 downto 0);
      wb_i        : in  t_wishbone_master_in;
      
      fsm_stb_i   : in  std_logic;
      fsm_full_o  : out std_logic;
      fsm_busy_o  : out std_logic;

      mux_pop_i   : in  std_logic;
      mux_dat_o   : out t_wishbone_data;
      mux_empty_o : out std_logic);
  end component;
  
  component eb_stream_narrow is
    generic(
      g_slave_width  : natural;
      g_master_width : natural);
    port(
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      slave_i  : in  t_wishbone_slave_in;
      slave_o  : out t_wishbone_slave_out;
      master_i : in  t_wishbone_master_in;
      master_o : out t_wishbone_master_out);
  end component;

  component eb_stream_widen is
    generic(
      g_slave_width  : natural;
      g_master_width : natural);
    port(
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      slave_i  : in  t_wishbone_slave_in;
      slave_o  : out t_wishbone_slave_out;
      master_i : in  t_wishbone_master_in;
      master_o : out t_wishbone_master_out);
  end component;
  
  component WB_bus_adapter_streaming_sg
    generic(
      g_adr_width_A : natural := 32;
      g_adr_width_B : natural := 32;
      g_dat_width_A : natural := 32;
      g_dat_width_B : natural := 16;
      g_pipeline    : natural);
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
    generic(
      g_width_IN  : natural := 16; 
      g_width_OUT : natural := 32);
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
    generic(
      g_width_IN  : natural := 16;
      g_width_OUT : natural := 32;
      g_protected : natural := 1);
    port(
      clk_i   : in  std_logic;
      nRst_i  : in  std_logic;
      d_i     : in  std_logic_vector(g_width_IN-1 downto 0);
      en_i    : in  std_logic;
      ld_i    : in  std_logic;
      q_o     : out std_logic_vector(g_width_OUT-1 downto 0);
      full_o  : out std_logic;
      empty_o : out std_logic);
  end component;
  
  component EB_checksum is
    port(
      clk_i  : in  std_logic;
      nRst_i : in  std_logic;
      en_i   : in  std_logic; 
      data_i : in  std_logic_vector(15 downto 0);
      done_o : out std_logic;
      sum_o  : out std_logic_vector(15 downto 0));
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
      valid_i  : in std_logic);
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

      valid_o : out std_logic);
  end component;

end package;
