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

signal rx_dat_i      : std_logic_vector(31 downto 0); 

signal r_rx_stall_o  : std_logic;
signal r_tag_stb_o   : std_logic;
signal r_tag_dat_o   : t_tag;
signal r_pass_stb_o  : std_logic;
signal r_pass_dat_o  : std_logic;
signal r_cfg_o       : t_wishbone_master_out;
signal r_wb_o        : t_wishbone_master_out;

signal s_state       : t_state_RX;

impure function f_reset is
begin
  r_rx_stall_o  <= '0';
  r_tag_stb_o   <= '0';
  r_tag_dat_o   <= (others => '0');
  r_pass_stb_o  <= '0';
  r_pass_dat_o  <= (others => '0');
  r_cfg_o       <= cc_dummy_master_out;
  r_wb_o        <= cc_dummy_master_out;
  r_state       <= EB_HDR;
  r_wait_mux    <= '0';
end f_reset;

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
end function reply;



impure function pass_on(data  : std_logic_vector) is
  return boolean is
  
  variable result : boolean := false;
begin
  s_pass_dat_o    <= data;
  s_tag_dat_o     <= c_tag_pass_on;
  
  if(pass_full_i = '0' AND tag_full_i = '0') then
    s_tag_stb_o   <= '1';
    s_pass_stb_o  <= '1';
    s_rx_stall_o  <= '0';
    result       := true;
  else
    s_tag_stb_o   <= '0';
    s_pass_stb_o  <= '0';
    s_rx_stall_o  <= '1';
    result       := false;
  end if;
  
  return result;
end pass_on;

impure function wb_write(adr : std_logic_vector; data  : std_logic_vector) is
begin
  s_pass_dat_o    <= data;
  s_tag_dat_o     <= c_tag_pass_on;
  
  if(pass_full_i = '0' AND tag_full_i = '0') then
    s_tag_stb_o   <= '1';
    s_pass_stb_o  <= '1';
    s_rx_stall_o  <= '0';
    result       := true;
  else
    s_tag_stb_o   <= '0';
    s_pass_stb_o  <= '0';
    s_rx_stall_o  <= '1';
    result       := false;
  end if;

end pass_on; 

impure function wb_read((adr : std_logic_vector) is
begin
  s_pass_dat_o    <= data;
  s_tag_dat_o     <= c_tag_pass_on;
  
  if(pass_full_i = '0' AND tag_full_i = '0') then
    s_tag_stb_o   <= '1';
    s_pass_stb_o  <= '1';
    s_rx_stall_o  <= '0';
    result       := true;
  else
    s_tag_stb_o   <= '0';
    s_pass_stb_o  <= '0';
    s_rx_stall_o  <= '1';
    result       := false;
  end if;

end pass_on;  

  
type t_state_RX is (EB_HDR, PROBE_ID, CYC_HDR, WR_ADR, WRITE, RD_ADR, READ, CYC_DONE, EB_DONE, ERRORS);

signal stall : std_logic;
signal r_rx_cyc_hdr   : EB_CYC;
signal r_tx_cyc_hdr   : EB_CYC;

begin


stall <= pass_full_i OR tag_full_i OR wbm_full_i OR (r_wait_mux and not mux_empty_i);


  fsm : process(clk_i, rstn_i)
  
  variable rx_frame_hdr : EB_HDR;
  variable tx_frame_hdr : EB_HDR;

  variable rx_cyc_hdr   : EB_CYC;
  variable tx_cyc_hdr   : EB_CYC;
  
  begin
    if (rstn_i = '0') then
      f_reset;
    elsif rising_edge(clk_i) then
      if(rx_cyc_i = '1') then
        if(rx_stb_i '1' and stall = '0') then
          
          r_pass_stb_o  <= '0';
          r_wb_o.stb    <= '0';
          r_cfg_o.stb   <= '0';
          
          case s_state is
            when EB_HDR   =>  rx_frame_hdr := TO_EB_HDR(rx_dat_i);
                              if( (rx_frame_hdr.EB_MAGIC                           = c_EB_MAGIC_WORD) 
                                  ((rx_frame_hdr.ADDR_SIZE and c_MY_EB_ADDR_SIZE) /= x"0")
                                  ((rx_frame_hdr.PORT_SIZE and c_MY_EB_PORT_SIZE) /= x"0")
                                  (rx_frame_hdr.VER                                = c_EB_VER)
                              
                              ) then --header valid ?             
                                tx_cyc_o <= NOT rx_frame_hdr.NO_RESPONSE;
                                tx_frame_hdr            := init_EB_hdr;
                                tx_frame_hdr.PROBE_RES  := rx_frame_hdr.PROBE;

                                pass_on(tx_frame_hdr);
                                --if pass on succesful, go to...
                                if(tx_frame_hdr.PROBE_RES = '1') then
                                  --...get probe id
                                  s_state <= PROBE_ID;
                                else
                                  --...get record header
                                  s_state <= CYC_HDR;   
                                end if;  
                                 
                              else
                                --bad eb header. drop all til cycle line is lowered again
                                s_state <= ERRORS;
                              
                              end if;
                               
            
            when PROBE_ID =>  pass_on(rx_dat_i);
                              s_state <= CYC_HDR;   
                                
            when CYC_HDR  =>  rx_cyc_hdr := TO_EB_HDR(rx_dat_i);
                              --check if record hdr is valid
                              tx_cyc_hdr := reply(rx_cyc_hdr);
                              r_wait_mux <= '0';    
                              if    (rx_cyc_hdr.WR_CNT > 0) then
                                --padding logic 1. insert padding instead of the header                                  
                                pass_on(x"00000000");                                    
                                s_state <= WR_ADR;  
                              elsif (rx_cyc_hdr.RD_CNT > 0) then
                                --no writes, no padding. insert the header                                     
                                pass_on(tx_cyc_hdr);                                
                                s_state <= RD_ADR;
                              else
                                --no writes, no padding. insert the header 
                                pass_on(tx_cyc_hdr);  
                                r_wait_mux  <= rx_cyc_hdr.DROP_CYC;                                
                                s_state     <= CYC_HDR;
                              end if;

                              r_tx_cyc_hdr  <= tx_cyc_hdr;                              
                              r_rx_cyc_hdr  <= rx_cyc_hdr;
                              

            when WR_ADR   =>  wb_adr <= rx_dat_i;
                              pass_on(x"00000000");
                              s_state <= WRITE;
                             
            when WRITE    =>  if(r_rx_cyc_hdr.WR_CNT > 0) then                          
                                r_rx_cyc_hdr.WR_CNT <= std_logic_vector(unsigned(r_rx_cyc_hdr.WR_CNT) -1);
                                if(r_rx_cyc_hdr.WR_FIFO = '0') then                                  
                                  wb_adr              <= wb_adr +4;
                                end if;
                                wb_write(wr_adr, rx_dat_i);
                                --padding logic 2. insert the header as the last write padding
                                if(r_rx_cyc_hdr.WR_CNT > 1) then
                                  pass_on(x"00000000"); 
                                else
                                  pass_on(tx_cyc_hdr);      
                                end if;                                
                              else
                                if (r_cyc_hdr.RD_CNT > 0) then
                                  s_state <= RD_ADR;
                                else
                                  r_wait_mux <= r_rx_cyc_hdr.DROP_CYC;  
                                  s_state <= CYC_HDR;
                                end if;
                              end if;      
            
            when RD_ADR   =>  pass_on(rx_dat_i); --pass the rx readback address as base write address to tx
                              s_state <= READ; 
                             
            when READ     =>  if(r_rx_cyc_hdr.RD_CNT > 0) then                          
                                r_rx_cyc_hdr.RD_CNT <= std_logic_vector(unsigned(r_rx_cyc_hdr.RD_CNT) -1);
                                wb_read(rx_dat_i); 
                              else
                                r_wait_mux <= r_rx_cyc_hdr.DROP_CYC;  
                                s_state <= CYC_HDR;
                              end if;    
                                                
            when ERRORS   =>  null;

            when others   =>  s_state <= ERRORS;                  
          end case;                                  
        
        end if; --rx_stb_i
      else
        r_wait_mux  <= '1';
        s_state     <= EB_HDR;      
      end if;  --rx_cyc_i
    end if; --clk edge  
  end process;      

end architecture;



