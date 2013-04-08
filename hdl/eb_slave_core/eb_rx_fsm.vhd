library IEEE;
--! Standard packages
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages
use work.eb_internals_pkg.all;
use work.eb_hdr_pkg.all;
use work.wishbone_pkg.all;

entity eb_rx_fsm is
  port(
    clk_i       : in  std_logic;
    rstn_i      : in  std_logic;
    
    rx_cyc_i    : in  std_logic;
    rx_stb_i    : in  std_logic;
    rx_dat_i    : in  std_logic_vector(31 downto 0);
    rx_stall_o  : out std_logic;
    tx_cyc_o    : out std_logic;
    
    mux_empty_i : in  std_logic;
    
    tag_stb_o   : out std_logic;
    tag_dat_o   : out t_tag;
    tag_full_i  : in  std_logic;
    
    pass_stb_o  : out std_logic;
    pass_dat_o  : out std_logic_vector(31 downto 0); 
    pass_full_i : in  std_logic;
    
    cfg_wb_o    : out t_wishbone_master_out;  -- cyc always hi
    cfg_full_i  : in  std_logic;
    
    wbm_wb_o    : out t_wishbone_master_out;
    wbm_full_i  : in  std_logic );
end entity;

architecture behavioral of eb_rx_fsm is

  type t_state_RX is (S_EB_HDR, S_PROBE_ID, s_CYC_HDR, S_WR_ADR, S_WRITE, S_RD_ADR, S_READ, S_ERRORS);
  
  signal r_tx_cyc_o    : std_logic;
  signal r_tag_stb_o   : std_logic;
  signal r_tag_dat_o   : t_tag;
  signal r_pass_stb_o  : std_logic;
  signal r_pass_dat_o  : t_wishbone_data;
  signal r_cfg_stb_o   : std_logic;
  signal r_wbm_stb_o   : std_logic;
  signal r_adr_o       : t_wishbone_address;
  signal r_we_o        : std_logic;
  signal r_wr_adr      : unsigned(31 downto 0);
  signal r_wait_mux    : std_logic;
  signal r_rx_cyc_hdr  : EB_CYC;
  signal r_tx_cyc_hdr  : EB_CYC;
  signal r_state       : t_state_RX;
  signal s_stall       : std_logic;
  
  function reply(rx_cyc_hdr : EB_CYC)
    return EB_CYC is
    variable tx_cyc_hdr : EB_CYC;
  begin
    tx_cyc_hdr := INIT_EB_CYC;
    tx_cyc_hdr.WCA_CFG  := rx_cyc_hdr.BCA_CFG;
    tx_cyc_hdr.RD_FIFO  := '0';
    tx_cyc_hdr.RD_CNT   := (others => '0');
    tx_cyc_hdr.WR_FIFO  := rx_cyc_hdr.RD_FIFO;
    tx_cyc_hdr.WR_CNT   := rx_cyc_hdr.RD_CNT;
    tx_cyc_hdr.SEL      := rx_cyc_hdr.SEL;
    tx_cyc_hdr.DROP_CYC := rx_cyc_hdr.DROP_CYC;
    return tx_cyc_hdr;
  end function;

begin
              
  rx_stall_o <= s_stall;
  tx_cyc_o   <= r_tx_cyc_o;
  tag_stb_o  <= r_tag_stb_o;
  tag_dat_o  <= r_tag_dat_o;
  pass_stb_o <= r_pass_stb_o;
  pass_dat_o <= r_pass_dat_o;
    
  cfg_wb_o.cyc <= '1';
  cfg_wb_o.stb <= r_cfg_stb_o;
  cfg_wb_o.adr <= r_adr_o;
  cfg_wb_o.we  <= r_we_o;
  cfg_wb_o.sel <= r_rx_cyc_hdr.sel;
  cfg_wb_o.dat <= rx_dat_i;
  
  wbm_wb_o.cyc <= not r_wait_mux or not mux_empty_i; -- Lower when mux is drained
  wbm_wb_o.stb <= r_wbm_stb_o;
  wbm_wb_o.adr <= r_adr_o;
  wbm_wb_o.we  <= r_we_o;
  wbm_wb_o.sel <= r_rx_cyc_hdr.sel;
  wbm_wb_o.dat <= rx_dat_i;
  
  -- Stall if FIFOs full or we are trying to quiet the bus
  s_stall <= pass_full_i OR tag_full_i OR wbm_full_i OR (r_wait_mux and not mux_empty_i);
  
  fsm : process(clk_i, rstn_i) is
    variable rx_frame_hdr : EB_HDR;
    variable tx_frame_hdr : EB_HDR;

    variable rx_cyc_hdr   : EB_CYC;
    variable tx_cyc_hdr   : EB_CYC;
  begin
    if (rstn_i = '0') then
      r_tx_cyc_o    <= '0';
      r_tag_stb_o   <= '0';
      r_tag_dat_o   <= (others => '0');
      r_pass_stb_o  <= '0';
      r_pass_dat_o  <= (others => '0');
      r_cfg_stb_o   <= '0';
      r_wbm_stb_o   <= '0';
      r_adr_o       <= (others => '0');
      r_we_o        <= '0';
      r_wr_adr      <= (others => '0');
      r_wait_mux    <= '0';
      r_rx_cyc_hdr  <= INIT_EB_CYC;
      r_tx_cyc_hdr  <= INIT_EB_CYC;
      r_state       <= S_EB_HDR;
    elsif rising_edge(clk_i) then
    
      -- By default, write nowhere in particular
      r_tag_stb_o  <= '0';
      r_pass_stb_o <= '0';
      r_cfg_stb_o  <= '0';
      r_wbm_stb_o  <= '0';
      
      if(rx_cyc_i = '0') then
        r_wait_mux <= '1'; -- stop next request until mux has drained
        r_state    <= S_EB_HDR;
        r_tx_cyc_o <= not mux_empty_i; -- !!! might combine packets
      elsif(rx_stb_i = '1' and s_stall = '0') then
        -- Every non-error state must write something
        
        case r_state is
          when s_EB_HDR =>
            rx_frame_hdr := TO_EB_HDR(rx_dat_i);
            if( (rx_frame_hdr.EB_MAGIC                           = c_EB_MAGIC_WORD) and
                ((rx_frame_hdr.ADDR_SIZE and c_MY_EB_ADDR_SIZE) /= x"0")            and
                ((rx_frame_hdr.PORT_SIZE and c_MY_EB_PORT_SIZE) /= x"0")            and
                (rx_frame_hdr.VER                                = c_EB_VER)
            ) then --header valid ?             
              -- Raise TX cycle line if this needs to be sent
              r_tx_cyc_o <= NOT rx_frame_hdr.NO_RESPONSE;
              
              -- Create output header
              tx_frame_hdr           := init_EB_hdr;
              tx_frame_hdr.PROBE_RES := rx_frame_hdr.PROBE;
              
              -- Write the header using pass fifo
              r_tag_stb_o  <= '1';
              r_tag_dat_o  <= c_tag_pass_on;
              r_pass_stb_o <= '1';
              r_pass_dat_o <= to_std_logic_vector(tx_frame_hdr);
              
              if(tx_frame_hdr.PROBE_RES = '1') then
                r_state <= S_PROBE_ID;
              else
                r_state <= S_CYC_HDR;
              end if;  
            else  --bad eb header. drop all til cycle line is lowered again
              r_state <= S_ERRORS;
            end if;
          
          when S_PROBE_ID =>
            -- Write the probe-id using pass fifo
            r_tag_stb_o  <= '1';
            r_tag_dat_o  <= c_tag_pass_on;
            r_pass_stb_o <= '1';
            r_pass_dat_o <= rx_dat_i;
            
            r_state <= s_CYC_HDR;   
          
          when S_CYC_HDR  =>
            rx_cyc_hdr := TO_EB_CYC(rx_dat_i);
            tx_cyc_hdr := reply(rx_cyc_hdr);
            r_tx_cyc_hdr  <= tx_cyc_hdr;                              
            r_rx_cyc_hdr  <= rx_cyc_hdr;
            
            r_wait_mux <= '0'; -- Re-enable pipelining
            
            -- Write padding/header using pass fifo
            r_tag_stb_o  <= '1';
            r_tag_dat_o  <= c_tag_pass_on;
            r_pass_stb_o <= '1';
            
            if (rx_cyc_hdr.WR_CNT /= 0) then
              --padding logic 1. insert padding instead of the header                                  
              r_pass_dat_o <= x"00000000";
              r_state <= S_WR_ADR;  
            elsif (rx_cyc_hdr.RD_CNT /= 0) then
              --no writes, no padding. insert the header
              r_pass_dat_o <= to_std_logic_vector(tx_cyc_hdr);
              r_state <= S_RD_ADR;
            else
              --no writes, no padding. insert the header 
              r_pass_dat_o <= to_std_logic_vector(tx_cyc_hdr);
              
              r_wait_mux <= rx_cyc_hdr.DROP_CYC;
              r_state    <= S_CYC_HDR;
            end if;
            
          when S_WR_ADR =>
            r_wr_adr <= unsigned(rx_dat_i);
            
            -- Write padding using pass fifo
            r_tag_stb_o  <= '1';
            r_tag_dat_o  <= c_tag_pass_on;
            r_pass_stb_o <= '1';
            r_pass_dat_o <= x"00000000";
            
            r_state <= S_WRITE;
          
          when S_WRITE =>
            -- Writes set to eb_wbm_fifo do not generate output
            if r_rx_cyc_hdr.BCA_CFG = '1' then
              r_cfg_stb_o <= '1';
            else
              r_wbm_stb_o <= '1';
            end if;
            
            r_adr_o <= std_logic_vector(r_wr_adr);
            r_we_o  <= '1';
            
            if(r_rx_cyc_hdr.WR_FIFO = '0') then
              r_wr_adr <= r_wr_adr + 4;
            end if;
            
            -- Write padding/header using pass fifo
            r_tag_stb_o  <= '1';
            r_tag_dat_o  <= c_tag_pass_on;
            r_pass_stb_o <= '1';
            
            if (r_rx_cyc_hdr.WR_CNT /= 1) then
              r_pass_dat_o <= x"00000000";
            else
              r_pass_dat_o <= to_std_logic_vector(r_tx_cyc_hdr);
              
              if (r_rx_cyc_hdr.RD_CNT /= 0) then
                r_state <= S_RD_ADR;
              else
                r_wait_mux <= r_rx_cyc_hdr.DROP_CYC;  
                r_state <= S_CYC_HDR;
              end if;
            end if;
            
            r_rx_cyc_hdr.WR_CNT <= r_rx_cyc_hdr.WR_CNT - 1;
              
          when S_RD_ADR =>
            -- Copy address using pass fifo
            r_tag_stb_o  <= '1';
            r_tag_dat_o  <= c_tag_pass_on;
            r_pass_stb_o <= '1';
            r_pass_dat_o <= rx_dat_i; --pass the rx readback address as base write address to tx
            
            r_state <= S_READ;
            
          when S_READ =>
            -- Get data from either cfg or wbm fifos
            r_tag_stb_o <= '1';
            if r_rx_cyc_hdr.BCA_CFG = '1' then
              r_cfg_stb_o <= '1';
              r_tag_dat_o <= c_tag_cfg_req;
            else
              r_wbm_stb_o <= '1';
              r_tag_dat_o <= c_tag_wbm_req;
            end if;
            
            r_adr_o <= rx_dat_i;
            r_we_o  <= '0';
            
            if(r_rx_cyc_hdr.RD_CNT = 1) then
              r_wait_mux <= r_rx_cyc_hdr.DROP_CYC;  
              r_state <= S_CYC_HDR;
            end if;
            
            r_rx_cyc_hdr.RD_CNT <= r_rx_cyc_hdr.RD_CNT - 1;
            
          when S_ERRORS =>
            null;

          when others =>
            r_state <= S_ERRORS;
        
        end case;
      end if; --rx_stb_i
    end if; --clk edge  
  end process;

end architecture;
