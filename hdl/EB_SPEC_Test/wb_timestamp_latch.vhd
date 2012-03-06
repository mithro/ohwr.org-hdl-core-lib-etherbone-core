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
  generic(g_num_triggers : natural := 32;
          g_fifo_depth   : natural := 9);
  port (
    ref_clk_i : in std_logic;           -- tranceiver clock domain
    sys_clk_i : in std_logic;           -- local clock domain
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
  signal triggers_synced          : std_logic_vector(g_num_triggers-1 downto 0);
  signal triggers_pos_edge_synced : std_logic_vector(g_num_triggers-1 downto 0);
  signal triggers_neg_edge_synced : std_logic_vector(g_num_triggers-1 downto 0);

  -- tm latch registers
  subtype t_timestamp is std_logic_vector(67 downto 0);
  type    t_tm_array is array (0 to g_num_triggers-1) of t_timestamp;
  signal  tm_array : t_tm_array;

  subtype t_word is std_logic_vector(31 downto 0);
  type    t_word_array is array (0 to g_num_triggers-1) of t_word;

  subtype t_cnt is std_logic_vector(f_log2_size(g_fifo_depth)-1 downto 0);
  type    t_cnt_array is array (0 to g_num_triggers-1) of t_cnt;

  signal rst_fifo    : std_logic_vector(g_num_triggers-1 downto 0);
  signal rd          : std_logic_vector(g_num_triggers-1 downto 0);
  signal we          : std_logic_vector(g_num_triggers-1 downto 0);
  signal rd_empty    : std_logic_vector(g_num_triggers-1 downto 0);
  signal wr_full     : std_logic_vector(g_num_triggers-1 downto 0);
  signal tm_fifo_in  : t_word_array;
  signal tm_fifo_out : t_word_array;

  signal rd_count : t_cnt_array;
  signal wr_count : t_cnt_array;
-- tm latch fsm

  type   t_state is (ARMED, WR_FIFO_WORD_0, WR_FIFO_WORD_1, WR_FIFO_WORD_2, DONE);
  type   t_state_array is array (0 to g_num_triggers-1) of t_state;
  signal state : t_state_array;
-------------------------------------------------------------------------------  



-----------------------------------------------------------------------------
  -- wb if registers
  signal address        : unsigned(7 downto 0);
  signal data           : std_logic_vector(g_num_triggers-1 downto 0);
  
  --fifo clear is asynchronous
  signal fifo_clear     : std_logic_vector(g_num_triggers-1 downto 0);
-- rd_empty signal is already in sys_clk domain
  signal fifo_data_rdy  : std_logic_vector(g_num_triggers-1 downto 0);
  
  -- these control registers must be synced to ref_clk domain
  signal trigger_active : std_logic_vector(g_num_triggers-1 downto 0);
  signal trigger_edge   : std_logic_vector(g_num_triggers-1 downto 0);
  
  signal trigger_active_ref_clk : std_logic_vector(g_num_triggers-1 downto 0);
  signal trigger_edge_ref_clk   : std_logic_vector(g_num_triggers-1 downto 0);
  
function pad_4_WB(reg : std_logic_vector) return std_logic_vector is 
variable ret : std_logic_vector(31 downto 0);
begin

	ret := std_logic_vector(to_unsigned(0, 32-reg'length)) & reg;
	return ret;
end function pad_4_WB;
  
begin  -- behavioral



-- show which fifos hold unread timestamps
  fifo_data_rdy <= (not(rd_empty));
  address       <= unsigned(wb_slave_i.adr(9 downto 2));
  data          <= wb_slave_i.dat(g_num_triggers-1 downto 0);

  trig_sync : for i in 0 to g_num_triggers-1 generate

  gc_sync_ffs_3 : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ref_clk_i,
        rst_n_i  => nRst_i,
        data_i   => trigger_edge(i),
        synced_o => trigger_edge_ref_clk(i),
        npulse_o => open,
        ppulse_o => open);
        
  gc_sync_ffs_2 : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => ref_clk_i,
        rst_n_i  => nRst_i,
        data_i   => trigger_active(i),
        synced_o => trigger_active_ref_clk(i),
        npulse_o => open,
        ppulse_o => open);

    gc_sync_ffs_1 : gc_sync_ffs
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
        g_data_width => 32,
        g_size       => g_fifo_depth,
        g_show_ahead => true,

        g_with_rd_empty        => true,
        g_with_rd_full         => false,
        g_with_rd_almost_empty => false,
        g_with_rd_almost_full  => false,
        g_with_rd_count        => true,

        g_with_wr_empty        => false,
        g_with_wr_full         => true,
        g_with_wr_almost_empty => false,
        g_with_wr_almost_full  => false,
        g_with_wr_count        => false,

        g_almost_empty_threshold => 0,
        g_almost_full_threshold  => 0
        )
      port map (
        rst_n_i           => rst_fifo(i),
        clk_wr_i          => ref_clk_i,
        d_i               => tm_fifo_in(i),
        we_i              => we(i),
        wr_empty_o        => open,
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

    rst_fifo(i) <= nRst_i and not fifo_clear(i);


    latch : process (ref_clk_i)
    begin  -- process latch
      
      
      if ref_clk_i'event and ref_clk_i = '1' then  -- rising clock edge
        if rst_fifo(i) = '0' then       -- synchronous reset (active low)
          state(i) <= ARMED;
          
        else
          we(i) <= '0';
          case state(i) is
            -- scan for trigger edge
            when ARMED => if(trigger_active_ref_clk(i) = '1') then
                              if((trigger_edge_ref_clk(i) = '1') and (triggers_pos_edge_synced(i) = '1')) then
                                tm_array(i) <= (tm_utc_i & tm_cycles_i);
                                state(i)    <= WR_FIFO_WORD_0;
                              end if;
                            if(trigger_edge_ref_clk(i) = '0' and triggers_neg_edge_synced(i) = '1') then
                              tm_array(i) <= (tm_utc_i & tm_cycles_i);
                              state(i)    <= WR_FIFO_WORD_0;
                            end if;
                          end if;
                          -- write first word to fifo
            when WR_FIFO_WORD_0 => tm_fifo_in(i) <= tm_array(i)(67 downto 36);
                                   we(i)    <= '1';
                                   state(i) <= WR_FIFO_WORD_1;
-- write second word to fifo
            when WR_FIFO_WORD_1 => tm_fifo_in(i) <= std_logic_vector(to_unsigned(0, 32-8)) & tm_array(i)(35 downto 28);
                                   we(i)    <= '1';
                                   state(i) <= WR_FIFO_WORD_2;
                                   -- write third word to fifo
            when WR_FIFO_WORD_2 => tm_fifo_in(i) <= std_logic_vector(to_unsigned(0, 32-28)) & tm_array(i)(27 downto 0);
                                   we(i)    <= '1';
                                   state(i) <= DONE;
-- capture done
            when DONE => state(i) <= ARMED;

            when others => state(i) <= ARMED;
          end case;
          

        end if;
      end if;
    end process latch;


    

  end generate trig_sync;

  wb_if : process (sys_clk_i)
    variable i : natural range 0 to g_num_triggers-1 := 0;
    
  begin  -- process wb_if
    
    
    if sys_clk_i'event and sys_clk_i = '1' then  -- rising clock edge
      if nRst_i = '0' then              -- synchronous reset (active low)
        trigger_active <= (others => '0');
        trigger_edge   <= (others => '1');
      else
        fifo_clear     <= (others => '0');
        rd             <= (others => '0');
        wb_slave_o.ack <= '0';

        if(wb_slave_i.cyc = '1' and wb_slave_i.stb = '1') then
          
          if(wb_slave_i.we = '1') then
            wb_slave_o.ack <= '1';
            case address is
              -- clear fifo
              when x"01" => fifo_clear     <= data;
-- Turn trigger channels on/off
              when x"03" => trigger_active <= trigger_active or data;  --set
              when x"04" => trigger_active <= trigger_active and not data;  --clr
-- Select pos ('1') or neg edge ('0') for trigger channel
              when x"06" => trigger_edge   <= trigger_active or data;  --set
              when x"07" => trigger_edge   <= trigger_active and not data;  --clr               


              when others => null;
            end case;
          else
            
            
            if((address >= 64) and (address <= 64+2*g_num_triggers-1)) then
              i := to_integer(unsigned(address(5 downto 1)));
              if(address(0) = '0') then
                                        --read fifo 
                wb_slave_o.dat <= tm_fifo_out(i);
                wb_slave_o.ack <= rd(i);
                rd(i)          <= '1';
              else
                                        --read cnt
                wb_slave_o.ack <= '1';
                wb_slave_o.dat <= pad_4_WB(rd_count(i));
              end if;
              
            else
              wb_slave_o.ack <= '1';
              case address is
-- read fifo "not empty" flag
                when x"00"  => wb_slave_o.dat <= pad_4_WB(fifo_data_rdy);
-- read channel active status
                when x"02"  => wb_slave_o.dat <= pad_4_WB(trigger_active);
-- read channel edge settings
                when x"05"  => wb_slave_o.dat <= pad_4_WB(trigger_edge);
                when others => null;
              end case;
-- read tm fifos or their read counters
              
            end if;
          end if;
        else
        -- direct outstanding fifo data to output
          wb_slave_o.dat <= tm_fifo_out(i);
          wb_slave_o.ack <= rd(i);
        end if;
        
      end if;
      
      
      
      
    end if;
  end process wb_if;


end behavioral;
