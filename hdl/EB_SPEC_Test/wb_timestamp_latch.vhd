--! @file wb_timestamp_latch.vhd
--! @brief Top file for EtherBone core
--!
--! Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--! @bug No know bugs.
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;

entity wb_timestamp_latch is
  generic(g_num_triggers : natural := 1;
          g_fifo_depth   : natural := 10);  
  port (
    ref_clk_i : in std_logic;              -- tranceiver clock domain
    sys_clk_i : in std_logic;              -- local clock domain
    nRSt_i    : in std_logic;

    triggers_i : in std_logic_vector(g_num_triggers-1 downto 0);  -- trigger lines for latch

    tm_time_valid_i : in std_logic;     -- timestamp valid flag
    tm_utc_i        : in std_logic_vector(39 downto 0);  -- UTC Timestamp
    tm_cycles_i     : in std_logic_vector(27 downto 0);  -- refclock cycle count
    pps_p_i         : in std_logic;  -- pps pulse, also signals reset of tm_cycles counter

    wb_slave_i : in  t_wishbone_slave_in;  -- Wishbone slave interface (sys_clk domain)
    wb_slave_o : out t_wishbone_slave_out
    );              

end wb_timestamp_latch;



architecture behavioral of wb_timestamp_latch is

  component gc_sync_ffs
    generic (
      g_sync_edge : string);
    port (
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      data_i   : in  std_logic;
      synced_o : out std_logic;
      npulse_o : out std_logic;
      ppulse_o : out std_logic);
  end component;

  component generic_async_fifo
    generic (
      g_data_width : natural;
      g_size       : natural;
      g_show_ahead : boolean := false;

      -- Read-side flag selection
      g_with_rd_empty        : boolean := true;   -- with empty flag
      g_with_rd_full         : boolean := false;  -- with full flag
      g_with_rd_almost_empty : boolean := false;
      g_with_rd_almost_full  : boolean := false;
      g_with_rd_count        : boolean := false;  -- with words counter

      g_with_wr_empty        : boolean := false;
      g_with_wr_full         : boolean := true;
      g_with_wr_almost_empty : boolean := false;
      g_with_wr_almost_full  : boolean := false;
      g_with_wr_count        : boolean := false;

      g_almost_empty_threshold : integer;   -- threshold for almost empty flag
      g_almost_full_threshold  : integer);  -- threshold for almost full flag
    port (
      rst_n_i           : in  std_logic := '1';
      clk_wr_i          : in  std_logic;
      d_i               : in  std_logic_vector(g_data_width-1 downto 0);
      we_i              : in  std_logic;
      wr_empty_o        : out std_logic;
      wr_full_o         : out std_logic;
      wr_almost_empty_o : out std_logic;
      wr_almost_full_o  : out std_logic;
      wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);
      clk_rd_i          : in  std_logic;
      q_o               : out std_logic_vector(g_data_width-1 downto 0);
      rd_i              : in  std_logic;
      rd_empty_o        : out std_logic;
      rd_full_o         : out std_logic;
      rd_almost_empty_o : out std_logic;
      rd_almost_full_o  : out std_logic;
      rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0));
  end component;

-------------------------------------------------------------------------------
  -- trigger sync chain
  subtype channel is std_logic_vector (g_num_triggers-1 downto 0);
  signal triggers_synced          : channel;
  signal triggers_pos_edge_synced : channel;
  signal triggers_neg_edge_synced : channel;

  -- tm latch registers
  subtype t_timestamp is std_logic_vector(67 downto 0);
    type    t_tm_array is array (0 to g_num_triggers-1) of t_timestamp;
  signal  tm_fifo_in  : t_tm_array;
  signal  tm_fifo_out : t_tm_array;

  subtype t_word is std_logic_vector(31 downto 0);
    type    t_word_array is array (0 to g_num_triggers-1) of t_word;
  signal tm_word0 : t_word_array;
  signal tm_word1 : t_word_array;
  signal tm_word2 : t_word_array;
  
  

  subtype t_cnt is std_logic_vector(f_log2_size(g_fifo_depth)-1 downto 0);
  type    t_cnt_array is array (0 to g_num_triggers-1) of t_cnt;

  signal nRst_fifo    : channel;
  signal rd          : channel;
  signal we          : channel;
  signal rd_empty    : channel;
  signal wr_empty    : channel;
  signal wr_full     : channel;
 

  signal rd_count : t_cnt_array;
  signal wr_count : t_cnt_array;
-- tm latch fsm

  


-------------------------------------------------------------------------------  



-----------------------------------------------------------------------------
  -- wb if registers
  signal address : unsigned(7 downto 0);
  signal data    : channel;
  signal stall : std_logic;

  subtype t_rd_req_cnt is natural range 0 to g_fifo_depth*3;
  type  t_rd_req_cnt_array is array (0 to g_num_triggers-1) of t_rd_req_cnt;
  signal fifo_rd_req_cnt : t_rd_req_cnt_array;
  

--fifo clear is asynchronous
  signal fifo_clear    : channel;
-- rd_empty signal is already in sys_clk domain
  signal fifo_data_rdy : channel;

  -- these control registers must be synced to ref_clk domain
  signal trigger_active : channel;
  signal trigger_edge   : channel;

  signal trigger_active_ref_clk : channel;
  signal trigger_edge_ref_clk   : channel;

  function pad_4_WB(reg : std_logic_vector) return std_logic_vector is
    variable ret : std_logic_vector(31 downto 0);
  begin

    ret := std_logic_vector(to_unsigned(0, 32-reg'length)) & reg;
    return ret;
  end function pad_4_WB;
  
begin  -- behavioral




  
  trig_sync : for i in 0 to g_num_triggers-1 generate

    tm_fifo_in(i) <= (tm_utc_i & tm_cycles_i);
    
     tm_word0(i) <= tm_fifo_out(i)(67 downto 36);
     tm_word1(i) <= std_logic_vector(to_unsigned(0, 32-8)) & tm_fifo_out(i)(35 downto 28);
     tm_word2(i) <= std_logic_vector(to_unsigned(0, 32-28)) & tm_fifo_out(i)(27 downto 0);
 
    

    sync_trig_edge_reg : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ref_clk_i,
        rst_n_i  => nRst_i,
        data_i   => trigger_edge(i),
        synced_o => trigger_edge_ref_clk(i),
        npulse_o => open,
        ppulse_o => open);

    sync_trig_active_reg : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ref_clk_i,
        rst_n_i  => nRst_i,
        data_i   => trigger_active(i),
        synced_o => trigger_active_ref_clk(i),
        npulse_o => open,
        ppulse_o => open);

    sync_triggers : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ref_clk_i,
        rst_n_i  => nRst_i,
        data_i   => triggers_i(i),
        synced_o => triggers_synced(i),
        npulse_o => triggers_neg_edge_synced(i),
        ppulse_o => triggers_pos_edge_synced(i));




    generic_async_fifo_1 : generic_async_fifo
      generic map (
        g_data_width => t_timestamp'length,  --utc + cycle count len 
        g_size       => g_fifo_depth,
        g_show_ahead => true,

        g_with_rd_empty        => true,
        g_with_rd_full         => false,
        g_with_rd_almost_empty => false,
        g_with_rd_almost_full  => false,
        g_with_rd_count        => true,

        g_with_wr_empty        => true,
        g_with_wr_full         => true,
        g_with_wr_almost_empty => false,
        g_with_wr_almost_full  => false,
        g_with_wr_count        => false,

        g_almost_empty_threshold => 0,
        g_almost_full_threshold  => 0
        )
      port map (
        rst_n_i           => nRst_fifo(i),
        clk_wr_i          => ref_clk_i,
        d_i               => tm_fifo_in(i),
        we_i              => we(i),
        wr_empty_o        => wr_empty(i),
        wr_full_o         => wr_full(i),
        wr_almost_empty_o => open,
        wr_almost_full_o  => open,
        wr_count_o        => open,
        clk_rd_i          => sys_clk_i,
        q_o               => tm_fifo_out(i),
        rd_i              => rd(i),
        rd_empty_o        => rd_empty(i),
        rd_full_o         => open,
        rd_almost_empty_o => open,
        rd_almost_full_o  => open,
        rd_count_o        => rd_count(i));

    -- purpose: latch timestamp on selected trigger edge
    -- type   : sequential
    -- inputs : ref_clk_i, trigger edges, timestamp data
    -- output : to fifo

    nRst_fifo(i) <= nRst_i and not fifo_clear(i);


    latch : process (ref_clk_i)
    begin  -- process latch
      if ref_clk_i'event and ref_clk_i = '1' then  -- rising clock edge
        if nRST_i = '0' then       -- synchronous reset (active low)
          we(i) <= '0';
        else
          ---------------------------------------------------------------------
          -- Latch timestamp if trigger is active and selected edge is detected
          ---------------------------------------------------------------------
          we(i) <= '0';
          if(trigger_active_ref_clk(i) = '1') then
            if((trigger_edge_ref_clk(i) = '0' and triggers_neg_edge_synced(i) = '1')
               or ((trigger_edge_ref_clk(i) = '1') and (triggers_pos_edge_synced(i) = '1'))) then
              we(i) <= '1';
            end if;
          end if;
          ---------------------------------------------------------------------
        end if;
      end if;
    end process latch;


    

  end generate trig_sync;



-- show which fifos hold unread timestamps
  fifo_data_rdy <= (not(rd_empty));
  address       <= unsigned(wb_slave_i.adr(9 downto 2));
  data          <= wb_slave_i.dat(g_num_triggers-1 downto 0);
  


  -----------------------------------------------------------------------------
  -- WB Interface
  -----------------------------------------------------------------------------
  wb_if : process (sys_clk_i)
    variable i : natural range 0 to g_num_triggers-1 := 0;

  begin  -- process wb_if
    
    if sys_clk_i'event and sys_clk_i = '1' then  -- rising clock edge
      if nRst_i = '0' then              -- synchronous reset (active low)
        trigger_active <= (others => '0');
        trigger_edge   <= (others => '0');
        rd             <= (others => '1');
      else
        -----------------------------------------------------------------------
        fifo_clear     <= (others => '0');
        rd             <= (others => '0');
       wb_slave_o.ack <= '0';
       wb_slave_o.err <= '0';
       stall <= '0';
       wb_slave_o.stall <= '0';
 
        
        if(wb_slave_i.cyc = '1' and wb_slave_i.stb = '1' and  stall = '0') then
          if(address < 128)then

            if(wb_slave_i.we = '1') then
            ---------------------------------------------------------------------
            -- Write standard config regs
            ---------------------------------------------------------------------
 
            case address is
              when x"00" => null;
              when x"01" => fifo_clear <= data; wb_slave_o.ack <= '1'; -- clear fifo
              when x"02" => null;
              when x"04" => trigger_active <= trigger_active or data; wb_slave_o.ack <= '1'; --set
              when x"05" => trigger_active <= trigger_active and not data; wb_slave_o.ack <= '1'; --clr
              when x"06" => null;    
              when x"07"  => trigger_edge <= trigger_active or data; wb_slave_o.ack <= '1'; --set
              when x"08"  => trigger_edge <= trigger_active and not data; wb_slave_o.ack <= '1'; --clr               
              when others => wb_slave_o.err <= '1';
            end case;
          else
            -------------------------------------------------------------------
            -- Read standard config regs
            -------------------------------------------------------------------
               case address is

                when x"00" => wb_slave_o.dat <= pad_4_WB(fifo_data_rdy);  wb_slave_o.ack <= '1';
                when x"01" => null;
                when x"02" => null;              
                when x"03" => wb_slave_o.dat <= pad_4_WB(trigger_active); wb_slave_o.ack <= '1';
                when x"04" => null;
                when x"05" => null;              
                when x"06"  => wb_slave_o.dat <= pad_4_WB(trigger_edge); wb_slave_o.ack <= '1';
                when others => wb_slave_o.err <= '1';
              end case;
            end if;
          else
            
            -------------------------------------------------------------------
            -- Counters and FIFOs
            -------------------------------------------------------------------
            if(address > 128+g_num_triggers*4-1) then
              wb_slave_o.err <= '1';
            else
              i := to_integer(unsigned(address(7 downto 3)));
              case address(2 downto 0) is
                when "000" => if(wb_slave_i.we = '1') then
                               rd(i)          <= '1';
                               wb_slave_o.ack <= '1';
                               wb_slave_o.stall <= '1';
                               stall <= '1';
                             else
                               wb_slave_o.err <= '1';
                             end if;
                when "001" => wb_slave_o.dat <= pad_4_WB(rd_count(i)); wb_slave_o.ack <= '1';              
                when "010" => wb_slave_o.dat <= tm_word0(i); wb_slave_o.ack <= '1';
                when "011" => wb_slave_o.dat <= tm_word1(i); wb_slave_o.ack <= '1';
                when "100" => wb_slave_o.dat <= tm_word2(i); wb_slave_o.ack <= '1';

                when others => wb_slave_o.err <= '1';
              end case;
            end if;
               
        end if;
      end if;
    end if;

  
    
    
    
  end if;
end process wb_if;


end behavioral;


