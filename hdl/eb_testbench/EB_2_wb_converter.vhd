--! @file EB_2_wb_converter.vhd
--! @brief EtherBone logic core
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

---! Standard library
library IEEE;
--! Standard packages
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages
use work.EB_HDR_PKG.all;
use work.wb32_package.all;

entity eb_2_wb_converter is
port(
		clk_i           : in  std_logic;                     --! System Clk
		nRst_i          : in  std_logic;                     --! active low sync reset

		--Eth MAC WB Streaming signals
		EB_RX_i         : in  wb32_slave_in;                 --! Streaming wishbone(record) sink from RX transport protocol block
		EB_RX_o         : out wb32_slave_out;                --! Streaming WB sink flow control to RX transport protocol block

		EB_TX_i         : in  wb32_master_in;                --! Streaming WB src flow control from TX transport protocol block
		EB_TX_o         : out wb32_master_out;               --! Streaming WB src to TX transport protocol block

		byte_count_rx_i : in  std_logic_vector(15 downto 0); --! Payload byte length from RX transport protocol block
		
		--config signals
		config_master_i     : in  wb32_master_in;                --! WB V4 interface to WB interconnect/device(s)
		config_master_o     : out wb32_master_out;                --! WB V4 interface to WB interconnect/device(s)
		
		
		
		--WB IC signals
		WB_master_i     : in  wb32_master_in;                --! WB V4 interface to WB interconnect/device(s)
		WB_master_o     : out wb32_master_out                --! WB V4 interface to WB interconnect/device(s)
		
		

);
end eb_2_wb_converter;

architecture behavioral of eb_2_wb_converter is

--Signals
------------------------------------------------------------------------------------------
--State Machines
------------------------------------------------------------------------------------------
constant c_width_int : integer := 24;
type t_state_RX is (IDLE, EB_HDR_REC, EB_HDR_PROC,  EB_HDR_PROBE_ID,  CYC_HDR_REC, CYC_HDR_READ_PROC, CYC_HDR_READ_GET_ADR, WB_READ_RDY, WB_READ, CYC_HDR_WRITE_PROC, CYC_HDR_WRITE_GET_ADR, WB_WRITE_RDY, WB_WRITE, CYC_DONE, EB_DONE, ERROR);
type t_state_TX is (IDLE, EB_HDR_INIT, EB_HDR_PROBE_ID, EB_HDR_PROBE_WAIT, PACKET_HDR_SEND, EB_HDR_SEND, RDY, CYC_HDR_INIT, CYC_HDR_SEND, BASE_WRITE_ADR_SEND, DATA_SEND, ZERO_PAD_WRITE, ZERO_PAD_WAIT, ERROR);



signal s_state_RX           : t_state_RX := IDLE;
signal s_state_TX           : t_state_TX := IDLE;

constant test : std_logic_vector(31 downto 0) := (others => '0');

------------------------------------------------------------------------------------------
--Wishbone Interfaces 
------------------------------------------------------------------------------------------
signal s_WB_master_i        : wb32_master_in;
signal s_WB_master_o        : wb32_master_out;

signal s_WB_STB             : std_logic;    
signal s_WB_ADR             : std_logic_vector(WB_master_o.ADR'left downto 0);    
signal s_WB_CYC             : std_logic;    
signal s_WB_WE              : std_logic;    
signal s_TX_STROBED         : std_logic;

signal s_WB_addr_inc        : unsigned(c_EB_ADDR_SIZE_n-1 downto 0);
signal s_WB_addr_cnt        : unsigned(c_EB_ADDR_SIZE_n-1 downto 0);

------------------------------------------------------------------------------------------
-- Byte/Pulse Counters
------------------------------------------------------------------------------------------
signal s_WB_ACK_cnt_big     : unsigned(8 downto 0);
alias  a_WB_ACK_cnt         : unsigned(7 downto 0) is s_WB_ACK_cnt_big(7 downto 0);
alias  a_WB_ACK_cnt_err     : unsigned(0 downto 0) is s_WB_ACK_cnt_big(8 downto 8);

signal s_EB_probe_wait_cnt  : unsigned(3 downto 0);
signal s_EB_TX_zeropad_cnt  : unsigned(7 downto 0);
signal s_EB_RX_byte_cnt     : unsigned(15 downto 0);
signal s_EB_TX_byte_cnt     : unsigned(15 downto 0);

signal debug_stb_cnt 		: natural := 0;
signal debug_byte_diff      : unsigned(15 downto 0);
signal debug_diff           : std_logic;
signal debugsum             : unsigned(15 downto 0);

------------------------------------------------------------------------------------------
--Config and Status Regs
------------------------------------------------------------------------------------------
signal s_WB_Config_o        : wb32_slave_out;
signal s_WB_Config_i        : wb32_slave_in;
signal s_ADR_CONFIG         : std_logic;

signal s_status_en          : std_logic;
signal s_status_clr         : std_logic;

------------------------------------------------------------------------------------------
--Etherbone Signals
------------------------------------------------------------------------------------------
signal s_EB_RX_ACK          : std_logic;
signal s_EB_RX_STALL        : std_logic;
signal s_EB_TX_STB          : std_logic;
signal s_packet_reception_complete : std_logic;

signal sink_valid           : std_logic;

------------------------------------------------------------------------------------------
--Etherbone Registers
------------------------------------------------------------------------------------------
constant c_WB_WORDSIZE      : natural             := 32;
constant c_EB_HDR_LEN       : unsigned(3 downto 0):= x"0";
signal s_EB_TX_base_wr_adr  : std_logic_vector(31 downto 0);
signal s_EB_packet_length   : unsigned(15 downto 0);

signal s_EB_RX_HDR          : EB_HDR;
signal s_EB_RX_CUR_CYCLE    : EB_CYC;
signal s_EB_TX_HDR          : EB_HDR;
signal s_EB_TX_CUR_CYCLE    : EB_CYC;

------------------------------------------------------------------------------------------
--Etherbone FIFO Buffers
------------------------------------------------------------------------------------------
signal s_tx_fifo_am_full    : std_logic;
signal s_tx_fifo_full       : std_logic;
signal s_tx_fifo_am_empty   : std_logic;
signal s_tx_fifo_empty      : std_logic;
signal s_tx_fifo_data       : std_logic_vector(31 downto 0);
signal s_tx_fifo_rd         : std_logic;
signal s_tx_fifo_clr        : std_logic;
signal s_tx_fifo_we         : std_logic;
signal s_tx_fifo_gauge      : std_logic_vector(3 downto 0);

signal s_rx_fifo_am_full    : std_logic;
signal s_rx_fifo_full       : std_logic;
signal s_rx_fifo_am_empty   : std_logic;
signal s_rx_fifo_empty      : std_logic;
signal s_rx_fifo_data       : std_logic_vector(31 downto 0);
signal s_rx_fifo_q          : std_logic_vector(31 downto 0);
signal s_rx_fifo_rd         : std_logic;
signal s_rx_fifo_clr        : std_logic;
signal s_rx_fifo_we         : std_logic;
signal s_rx_fifo_gauge      : std_logic_vector(3 downto 0);
------------------------------------------------------------------------------------------


signal PROBE_ID             : std_logic_vector(31 downto 0);

constant WBM_Zero_o        : wb32_master_out :=     (CYC => '0',
                                                STB => '0',
                                                ADR => (others => '0'),
                                                SEL => (others => '0'),
                                                WE  => '0',
                                                DAT => (others => '0'));
                                                
constant WBS_Zero_o        : wb32_slave_out :=     (ACK   => '0',
                                                ERR   => '0',
                                                RTY   => '0',
                                                STALL => '0',
                                                DAT   => (others => '0'));
                                                
component alt_FIFO_am_full_flag IS
    PORT
    (
        clock        : IN STD_LOGIC ;
        data        : IN STD_LOGIC_VECTOR (31 DOWNTO 0);
        rdreq        : IN STD_LOGIC ;
        sclr        : IN STD_LOGIC ;
        wrreq        : IN STD_LOGIC ;
        almost_empty        : OUT STD_LOGIC ;
        almost_full        : OUT STD_LOGIC ;
        empty        : OUT STD_LOGIC ;
        full        : OUT STD_LOGIC ;
        q            : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
        usedw        : OUT STD_LOGIC_VECTOR (3 DOWNTO 0)
    );
end component alt_FIFO_am_full_flag;

begin

TX_FIFO : alt_FIFO_am_full_flag
port map(
        clock            => clk_i,
        data            => s_tx_fifo_data,
        rdreq            => s_tx_fifo_rd,
        sclr            => s_tx_fifo_clr,
        wrreq            => s_tx_fifo_we,
        almost_empty    => s_tx_fifo_am_empty,
        almost_full        => s_tx_fifo_am_full,
        empty            => s_tx_fifo_empty,
        full            => s_tx_fifo_full,
        q                => EB_TX_o.DAT,
        usedw            => s_tx_fifo_gauge
    );

--strobe out as long as there is data left    
EB_TX_o.STB <= NOT s_tx_fifo_empty;

--read data from RX fifo as long as TX interface is free
s_tx_fifo_rd            <= NOT EB_TX_i.STALL;

--write in pending data as long as there is space left
s_tx_fifo_we            <= s_EB_TX_STB AND NOT s_tx_fifo_full; 
   
    RX_FIFO : alt_FIFO_am_full_flag
port map(
		clock        => clk_i,
		data         => EB_RX_i.DAT,
		rdreq        => s_rx_fifo_rd,
		sclr         => s_rx_fifo_clr,
		wrreq        => s_rx_fifo_we,
		almost_empty => open,
		almost_full  => s_rx_fifo_am_full,
		empty        => s_rx_fifo_empty,
		full         => s_rx_fifo_full,
		q            => s_rx_fifo_q,
		usedw        => s_rx_fifo_gauge
    );    

--BUG: almost_empty flag is stuck after hitting empty repeatedly.
--create our own for now
s_rx_fifo_am_empty <= '1' when unsigned(s_rx_fifo_gauge) <= 1
            else '0';

--workaround to avoid creation of two drivers for the s_WB_master_o record            
s_WB_master_o.DAT     <= s_rx_fifo_q;
s_WB_master_o.STB    <= s_WB_STB;

--when reading, incoming rx data goes on the WB address lines
s_WB_master_o.ADR    <=     s_rx_fifo_q when s_state_RX   = WB_READ
                else s_WB_ADR;
                
s_WB_master_o.CYC   <= s_WB_CYC;    
s_WB_master_o.WE    <= s_WB_WE;    
EB_RX_o.STALL       <= s_rx_fifo_am_full;
EB_RX_o.ACK         <= s_EB_RX_ACK;
EB_RX_o.ERR         <= '0';

s_rx_fifo_we             <= EB_RX_i.STB AND NOT (s_rx_fifo_am_full); -- OR s_packet_reception_complete);

	
--MUX lines: WB master / config space master
---------------------------------
Mux_WB_Cfg_in : with s_ADR_CONFIG select
s_WB_master_i <=    config_master_i  when '1',
                    WB_master_i    when others;

-- select WB Master Port Out: Tie to ground / Signal s_WB_master_o
Mux_WB_out  : with s_ADR_CONFIG select
WB_master_o <=      WBM_Zero_o when '1',
                    s_WB_master_o     when others;
                        
-- select WB Master Port Out: Tie to ground / Signal s_WB_master_o
Mux_Cfg_out  : with s_ADR_CONFIG select
config_master_o  <= s_WB_master_o when '1',
                    WBM_Zero_o     when others;                        
-----------------------------------


        
        
        
debug_diff <= '1' when debug_byte_diff > 0 else '0';

count_io : process(clk_i)
begin
    if rising_edge(clk_i) then
        
        if (nRST_i = '0') then
            s_EB_RX_byte_cnt <= (others => '0');
            s_EB_TX_byte_cnt <= (others => '0');
            s_WB_ACK_cnt_big <= (others => '0');        
        else
            
            
            --Counter: RX bytes received
            if(s_state_RX   = IDLE) then
                s_EB_RX_byte_cnt <= (others => '0');
            else
                if(s_rx_fifo_we = '1') then
                    s_EB_RX_byte_cnt <= s_EB_RX_byte_cnt + 4;    
                end if;
            end if;
            -- packet reception is not complete if min packet size not reached and < s_EB_packet_length
            --
            if((s_EB_RX_byte_cnt < s_EB_packet_length) OR (s_EB_RX_byte_cnt < 16)) then
                s_packet_reception_complete <= '0';
            else
                s_packet_reception_complete <= '1';
            end if;
            
            --Counter: WB ACKs received
            if(s_state_RX   = IDLE) then
                s_WB_ACK_cnt_big <= (others => '0');
            else
                if(s_state_RX   = CYC_HDR_WRITE_PROC) then
                    a_WB_ACK_cnt         <= s_EB_RX_CUR_CYCLE.RD_CNT + s_EB_RX_CUR_CYCLE.WR_CNT;
                elsif(s_WB_master_i.ACK = '1') then
                    a_WB_ACK_cnt                 <= a_WB_ACK_cnt -1;
                end if;
            end if;
            
            --Counter: WB ACKs received
            if(s_state_RX   = IDLE) then
                debug_stb_cnt <= 0;
            else
                if(s_state_RX   = CYC_HDR_WRITE_PROC) then
                    debug_stb_cnt <= 0;
                elsif(s_WB_master_o.STB = '1') then
                    debug_stb_cnt                <= debug_stb_cnt +1;
                end if;
            end if;
            
            --Counter: TX bytes sent
            if(s_state_TX   = IDLE) then
                s_EB_TX_byte_cnt <= (others => '0');
            else
                if(s_tx_fifo_we = '1') then
                    s_EB_TX_byte_cnt <= s_EB_TX_byte_cnt + 4;
                end if;    
            end if;
            
            --Counter: Probewait
            if(s_state_TX   = EB_HDR_PROBE_ID) then
                s_EB_probe_wait_cnt <= (others => '0');
            else
                if(s_state_TX   = EB_HDR_PROBE_WAIT) then
                    s_EB_probe_wait_cnt <= s_EB_probe_wait_cnt +1;
                end if;    
            end if;
            
            
        end if;
    end if;    
end process;

p_state_transition: process(clk_i)
begin
    if rising_edge(clk_i) then

    --==========================================================================
    -- SYNC RESET
--==========================================================================

        if (nRST_i = '0') then

            s_state_TX          <= IDLE;
            s_state_RX          <= IDLE;
            
        else
            -- RX cycle line lowered before all words were transferred
            if    (s_EB_RX_byte_cnt < s_EB_packet_length
            AND  EB_RX_i.CYC = '0') then
                report "EB: PACKET WAS ABORTED" severity note;
            --    ERROR: -- RX cycle line lowered before all words were transferred
                s_state_RX                   <= IDLE;
                s_state_TX                   <= IDLE;
            --
            elsif(s_EB_RX_byte_cnt > s_EB_packet_length AND NOT (s_EB_RX_byte_cnt < 16)) then
                report "EB: PACKET TOO LONG" severity note;
                s_state_RX                   <= IDLE;
                s_state_TX                   <= IDLE;
            else
            
                case s_state_RX   is
                    when IDLE                   =>  if(s_rx_fifo_empty = '1') then
                                                        s_state_TX                   <= IDLE;
                                                        s_state_RX                   <= EB_HDR_REC;
                                                        report "EB: RDY" severity note;
                                                    end if;
                                            
                    when EB_HDR_REC             =>  if(EB_RX_i.CYC = '1' AND s_rx_fifo_empty = '0') then
                                                        s_state_RX       <= EB_HDR_PROC;
                                                    end if;
                                            
                    when EB_HDR_PROC            =>  if(    (s_EB_RX_HDR.EB_MAGIC /= c_EB_MAGIC_WORD)     -- not EB
                                                        OR     (s_EB_RX_HDR.VER /= c_EB_VER)                -- wrong version
                                                        OR    ((s_EB_RX_HDR.ADDR_SIZE AND c_MY_EB_ADDR_SIZE) = x"0")                    -- wrong size
                                                        OR  ((s_EB_RX_HDR.PORT_SIZE AND c_MY_EB_PORT_SIZE)= x"0"))                    -- wrong size
                                                    then
                                                        s_state_RX   <= ERROR;
                                                        report "EB: MALFORMED PACKET" severity note;
                                                    else
                                                        --eb hdr seems valid, prepare answering packet. Prefill RX buffer
                                                        if(unsigned(s_rx_fifo_gauge) > 3) then
                                                             s_state_RX   <= CYC_HDR_REC;
                                                            s_state_TX   <= EB_HDR_INIT; 
                                                        else  
                                                          report "EB: Waiting for buffer ..." severity note;
                                                        end if;
                                                        if(s_EB_RX_HDR.PROBE = '1') then -- no probe, prepare cycle reception
                                                                s_state_RX   <= EB_HDR_PROBE_ID ;
                                                                s_state_TX   <= EB_HDR_INIT;    
                                                        end if;   
                                                    end if;
                    
                  when EB_HDR_PROBE_ID          =>  s_state_RX   <= EB_DONE;  
                                        
                    when CYC_HDR_REC            =>  if(s_rx_fifo_empty = '0') then
                                                            s_state_RX    <= CYC_HDR_WRITE_PROC;
                                                    end if;
                                            
                    when CYC_HDR_WRITE_PROC     =>  if(s_EB_RX_CUR_CYCLE.WR_CNT > 0) then
                                                        s_state_RX   <=  CYC_HDR_WRITE_GET_ADR;
                                                    else
                                                        s_state_RX           <=  CYC_HDR_READ_PROC;
                                                    end if;
                                                
                    
                    when CYC_HDR_WRITE_GET_ADR  =>  if(s_rx_fifo_am_empty = '0') then
                                                        s_state_RX           <= WB_WRITE_RDY;
                                                    end if;
                                                    
                    when WB_WRITE_RDY           =>  if(s_state_TX   = RDY) then
                                                        s_state_RX               <= WB_WRITE;
                                                        s_state_TX               <= ZERO_PAD_WRITE;
                                                    end if;        
                    
                    when WB_WRITE               =>  if(s_EB_RX_CUR_CYCLE.WR_CNT = 0 ) then --underflow of RX_cyc_wr_count
                                                        s_state_RX                   <= CYC_HDR_READ_PROC;
                                                    end if;
                    
                    when CYC_HDR_READ_PROC      =>  if(s_state_TX   = RDY) then
                                                        --are there reads to do?
                                                        
                                                        if(s_EB_RX_CUR_CYCLE.RD_CNT > 0) then
                                                            s_state_TX           <= CYC_HDR_INIT;
                                                            s_state_RX           <= CYC_HDR_READ_GET_ADR;
                                                        else
                                                            s_state_RX           <=  CYC_DONE;
                                                        end if;
                                                        
                                                    end if;
                        
                    when CYC_HDR_READ_GET_ADR   =>  if(s_rx_fifo_am_empty = '0') then
                                                        s_state_RX               <= WB_READ_RDY;
                                                    end if;
                                                    
                    when WB_READ_RDY            =>  if(s_state_TX   = RDY) then
                                                        s_state_RX           <= WB_READ;
                                                        s_state_TX           <= BASE_WRITE_ADR_SEND;
                                                    end if;

                    when WB_READ                =>  if(s_EB_RX_CUR_CYCLE.RD_CNT = 0) then
                                                        s_state_RX                   <= CYC_DONE;
                                                    end if;

                    when CYC_DONE               =>  if(a_WB_ACK_cnt = 0 AND s_tx_fifo_we = '0') then
                                                        if((s_EB_RX_byte_cnt < s_EB_packet_length) OR (s_EB_RX_byte_cnt = s_EB_packet_length AND s_rx_fifo_am_empty = '0')) then    
                                                            s_state_RX       <= CYC_HDR_REC;
                                                        else
                                                            --no more cycles to do, packet is done. reset FSMs
                                                            if(s_tx_fifo_empty = '1') then
                                                                s_state_RX               <= EB_DONE;
                                                                s_state_TX               <= IDLE;
                                                            end if;
                                                        end if;
                                                    elsif(a_WB_ACK_cnt_err = "1") then
                                                        s_state_RX   <= ERROR;
                                                    end if;
                                        
                    when EB_DONE                =>  if(s_state_TX   = IDLE OR s_state_TX   = RDY) then -- 1. packet done, 2. probe done
                                                        s_state_RX   <= IDLE;
                                                        s_state_TX   <= IDLE;
                                                    end if;    

                    when ERROR                  =>  s_state_TX  <= IDLE;
                                                    s_state_RX   <= IDLE;
                                                    if((s_EB_RX_HDR.VER             /= c_EB_VER)                -- wrong version
                                                        OR (s_EB_RX_HDR.ADDR_SIZE     /= c_MY_EB_ADDR_SIZE)                    -- wrong size
                                                        OR (s_EB_RX_HDR.PORT_SIZE     /= c_MY_EB_PORT_SIZE))    then
                                                        s_state_TX   <= ERROR;
                                                    end if;
                                                    
                    when others                 =>  s_state_RX   <= IDLE;
                end case;
            
                
                case s_state_TX   is
                    when IDLE                   =>  null;
                                                
                    when RDY                    =>  null;--wait
                                                
                    when EB_HDR_INIT            =>  s_state_TX <= PACKET_HDR_SEND;
                    
                    when PACKET_HDR_SEND        =>  s_state_TX <=  EB_HDR_SEND;
                                                
                    --TODO: padding to 64bit alignment
                    when EB_HDR_SEND            =>  if(s_tx_fifo_full = '0') then    
                                                        if(s_EB_RX_HDR.PROBE = '1') then
                                                            s_state_TX   <=  EB_HDR_PROBE_ID;
                                                        else
                                                            s_state_TX   <=  RDY;
                                                        end if;
                                                    end if;
                    
                    when EB_HDR_PROBE_ID =>         s_state_TX   <=  EB_HDR_PROBE_WAIT;
                                                    
                                                    
                                                    
                                                    
                    when EB_HDR_PROBE_WAIT =>       if(s_EB_probe_wait_cnt  > 3 AND s_tx_fifo_empty = '1' ) then    
                                                      s_state_TX  <= IDLE;
                                                    end if;
                    
                                                                           
                    
                    when CYC_HDR_INIT           =>  s_state_TX <= CYC_HDR_SEND;
                                            
                    when CYC_HDR_SEND           =>  if(s_tx_fifo_full = '0') then
                                                        s_state_TX   <=  RDY;
                                                    end if;

                    when BASE_WRITE_ADR_SEND    =>  if(s_tx_fifo_full = '0') then
                                                        s_state_TX <= DATA_SEND;
                                                    end if;    
            
                    when DATA_SEND              =>  --only write at the moment!
                                                    if(s_EB_TX_CUR_CYCLE.WR_CNT = 0) then
                                                        s_state_TX   <=  RDY;
                                                    end if;
                    
                    when ZERO_PAD_WRITE         =>  if(s_EB_TX_zeropad_cnt = 0) then
                                                        s_state_TX   <= RDY;
                                                    end if;    
                                            
                    when ZERO_PAD_WAIT          =>  null;
                    
                    when others                 =>  s_state_TX   <= IDLE;
                end case;
            
            end if;
            
        end if;
    end if;

end process p_state_transition;

p_state_output: process(clk_i)
begin
    if rising_edge(clk_i) then

    --==========================================================================
    -- SYNC RESET
--==========================================================================

        if (nRST_i = '0') then

			s_EB_TX_HDR        <= init_EB_HDR;
			PROBE_ID           <= X"1337BEEF";
			s_EB_TX_CUR_CYCLE  <= to_EB_CYC(test);
			s_EB_TX_base_wr_adr<= (others => '0');
			s_EB_RX_CUR_CYCLE  <= to_EB_CYC(test);
			
			s_EB_RX_ACK        <= '0';
			
											
			EB_TX_o.CYC        <= '0';
			
			EB_TX_o.ADR        <= (others => '0');
			EB_TX_o.SEL        <= (others => '1');
			
			EB_TX_o.WE         <= '1';

			s_EB_RX_STALL      <= '0';
		
			s_WB_addr_cnt      <= (others => '0');
			s_EB_packet_length <= (others => '0');
			s_ADR_CONFIG       <=    '0';
			s_tx_fifo_clr      <= '1';
			s_rx_fifo_clr      <= '1';
			s_status_en        <= '0';
			s_status_clr       <= '0';
			
			
			s_WB_STB           <= '0';
			s_WB_WE            <= '0';
			s_WB_ADR           <= (others => '0');    
			
			s_EB_TX_zeropad_cnt<= (others => '0');    
		else
			
				
			s_EB_RX_ACK        <= s_rx_fifo_we; --EB_RX_i.STB AND NOT slave_RX_stream_STALL;
			
			
			
			s_rx_fifo_rd       <= '0';    
			s_WB_WE            <= '0';
			s_WB_STB           <= '0';
			s_EB_TX_STB        <= '0';
			
			s_status_en        <= '0';
			s_status_clr       <= '0';
			
			s_tx_fifo_clr      <= '0';
			s_rx_fifo_clr      <= '0';    
            
            
            
            
            case s_state_RX   is
                when IDLE                   =>  s_tx_fifo_clr <= '1';
                                                s_rx_fifo_clr <= '1';
                                                s_status_clr  <= '1';
                                            
                when EB_HDR_REC             =>  if(EB_RX_i.CYC = '1' AND s_rx_fifo_empty = '0') then
                                                    s_EB_RX_HDR <= to_EB_HDR(s_rx_fifo_q);
                                                    s_EB_packet_length <= unsigned(byte_count_rx_i);
                                                    s_rx_fifo_rd              <= '1';    
                                                end if;
                                        
                when EB_HDR_PROC            =>  null;
                
                
                when EB_HDR_PROBE_ID        =>  if(EB_RX_i.CYC = '1' AND s_rx_fifo_empty = '0') then
                                                    PROBE_ID <= s_rx_fifo_q;
                                                    s_rx_fifo_rd              <= '1';    
                                                end if;
                                               
                                    
                when CYC_HDR_REC            =>  if(s_rx_fifo_empty = '0') then
                                                    s_EB_RX_CUR_CYCLE    <= TO_EB_CYC(s_rx_fifo_q);
                                                    s_rx_fifo_rd <= '1';
                                                end if;
                                        
                when CYC_HDR_WRITE_PROC     =>  if(s_EB_RX_CUR_CYCLE.WR_CNT > 0) then
                                                --setup word counters
                                                    s_ADR_CONFIG <=    s_EB_RX_CUR_CYCLE.WCA_CFG;
                                                end if;
                                            
                
                when CYC_HDR_WRITE_GET_ADR  =>  if(s_rx_fifo_am_empty = '0') then
                                                    s_WB_addr_cnt     <= unsigned(s_rx_fifo_q);
                                                    s_rx_fifo_rd     <= '1'; -- only stall RX if we got an adress, otherwise continue listening
                                                end if;
                                                
                when WB_WRITE_RDY           =>  if(s_state_TX   = RDY) then
                                                    s_WB_CYC     <= '1';
                                                    -- only stall RX if we got an adress, otherwise continue listening
                                                    --s_WB_master_o.DAT        <= s_rx_fifo_q;
                                                    if(s_EB_RX_CUR_CYCLE.RD_CNT > 0) then
                                                        s_EB_TX_zeropad_cnt             <= s_EB_RX_CUR_CYCLE.WR_CNT+1; --wr start addr
                                                    else
                                                        s_EB_TX_zeropad_cnt             <= s_EB_RX_CUR_CYCLE.WR_CNT+2; --wr start addr + header because read block is not called
                                                    end if;            
                                                end if;        
                
                when WB_WRITE               =>  s_status_en        <= s_WB_master_i.ACK;
                                                if(s_EB_RX_CUR_CYCLE.WR_CNT > 0 ) then --underflow of RX_cyc_wr_count
                                                                                            
							s_WB_ADR         <= std_logic_vector(s_WB_addr_cnt);
							s_WB_WE        <= '1';
						
							-- case 1: elements 0 -> n-2
							-- case 2: n-1
							-- done to prevent buffer underrun    
						
							if(s_rx_fifo_am_empty = '0') then
								s_WB_STB      <= '1';
								if(s_WB_master_i.STALL = '0') then
									s_rx_fifo_rd     <= '1';
									s_EB_RX_CUR_CYCLE.WR_CNT     <= s_EB_RX_CUR_CYCLE.WR_CNT-1;
									if(s_EB_RX_CUR_CYCLE.WR_FIFO = '0') then
										s_WB_addr_cnt             <= s_WB_addr_cnt + 4;
									end if;
								end if;
							elsif(s_rx_fifo_empty = '0' AND (s_EB_RX_byte_cnt = s_EB_packet_length)) then
								s_WB_STB      <= '1';
								if(s_WB_master_i.STALL = '0') then
									s_EB_RX_CUR_CYCLE.WR_CNT <= s_EB_RX_CUR_CYCLE.WR_CNT-1;
								end if;
							end if;
                                                
                                                end if;
                
                when CYC_HDR_READ_PROC      =>  if(s_state_TX   = RDY) then
                                                    --are there reads to do?
                                                    
                                                    if(s_EB_RX_CUR_CYCLE.RD_CNT > 0) then
                                                        --setup word counters
                                                        s_ADR_CONFIG <=    s_EB_RX_CUR_CYCLE.RCA_CFG;

                                                    end if;
                                                    
                                                end if;
                
                when CYC_HDR_READ_GET_ADR   =>  if(s_rx_fifo_am_empty = '0') then
                                                    --wait for ready from tx output
                                                    s_EB_TX_base_wr_adr     <= s_rx_fifo_q;
                                                    s_rx_fifo_rd     <= '1';
                                                end if;
                                                
                                                
                when WB_READ_RDY            =>  if(s_state_TX   = RDY) then
                                                    s_WB_CYC <= '1';
                                                end if;

                when WB_READ                =>  s_status_en        <= s_WB_master_i.ACK;
                                                if(s_state_TX = DATA_SEND AND s_EB_RX_CUR_CYCLE.RD_CNT > 0) then
                                                    
                                                    --s_WB_ADR     <= s_rx_fifo_q;
                                                    --only go down to almost empty to keep pipeline filled
                                                    if((s_rx_fifo_am_empty = '0') ) then
                                                        if(s_tx_fifo_am_full = '0') then
                                                            s_WB_STB      <= '1';
                                                            if(s_WB_master_i.STALL = '0') then
                                                                s_rx_fifo_rd <= '1';
                                                                s_EB_RX_CUR_CYCLE.RD_CNT <= s_EB_RX_CUR_CYCLE.RD_CNT-1;
                                                            end if;
                                                        end if;
                                                    else
                                                        --if these are the last bytes of the packet, empty pipeline.                                                    
                                                        if(s_rx_fifo_empty = '0' AND (s_EB_RX_byte_cnt = s_EB_packet_length)) then
                                                            if(s_tx_fifo_am_full = '0') then
                                                                s_WB_STB      <= '1';
                                                            if(s_WB_master_i.STALL = '0') then
                                                                s_EB_RX_CUR_CYCLE.RD_CNT <= s_EB_RX_CUR_CYCLE.RD_CNT-1;
                                                            end if;
                                                        end if;
                                                        
                                                        end if;
                                                    end if;
                                                end if;
                                    
                when CYC_DONE               =>  s_status_en        <= s_WB_master_i.ACK;
                                                if(a_WB_ACK_cnt = 0 AND s_tx_fifo_we = '0') then
                                                    --keep cycle line high if no drop requested
                                                    s_WB_CYC             <= NOT s_EB_RX_CUR_CYCLE.DROP_CYC;
                                                    s_status_clr     <= s_EB_RX_CUR_CYCLE.DROP_CYC;                                            
                                                end if;
                                    
                when EB_DONE                =>  report "EB: PACKET COMPLETE" severity note;
                                                --TODO: test multi packet mode
                                                s_WB_CYC <= NOT s_EB_RX_CUR_CYCLE.DROP_CYC;
                                                --make sure there is no running transfer before resetting FSMs, also do not start a new packet proc before cyc has been lowered

                when ERROR                  =>  report "EB: ERROR" severity warning;
                                                s_WB_CYC <= '0';
            end case;
        
        
        
            
            

            case s_state_TX   is
                when IDLE                   =>	EB_TX_o.CYC <= '0';
                                            
                when RDY                    =>  null;--wait
                                        
                when EB_HDR_INIT            =>  s_EB_TX_HDR        <= init_EB_hdr;
                                                s_EB_TX_HDR.PROBE_RES <= s_EB_RX_HDR.PROBE;
                                                
                                        
                when PACKET_HDR_SEND        =>  EB_TX_o.CYC <= '1';
                                            --using stall line for signalling the completion of Eth packet hdr
                
                --TODO: padding to 64bit alignment
                when EB_HDR_SEND            =>  s_EB_TX_STB <= '1';
                                                s_tx_fifo_data <= to_std_logic_vector(s_EB_TX_HDR);
                                                   
                when EB_HDR_PROBE_ID        =>  s_EB_TX_STB <= '1';
                                                s_tx_fifo_data <= PROBE_ID;
                                                 
                                        
                when CYC_HDR_INIT           =>  s_EB_TX_CUR_CYCLE.WCA_CFG     <= s_EB_RX_CUR_CYCLE.BCA_CFG;
                                                s_EB_TX_CUR_CYCLE.RD_FIFO    <= '0';
                                                s_EB_TX_CUR_CYCLE.RD_CNT    <= (others => '0');
                                                s_EB_TX_CUR_CYCLE.WR_FIFO     <= s_EB_RX_CUR_CYCLE.RD_FIFO;
                                                s_EB_TX_CUR_CYCLE.WR_CNT     <= s_EB_RX_CUR_CYCLE.RD_CNT;
                                        
                when CYC_HDR_SEND           =>  s_tx_fifo_data     <= TO_STD_LOGIC_VECTOR(s_EB_TX_CUR_CYCLE);
                                                s_EB_TX_STB                     <= '1';
                                        
                when BASE_WRITE_ADR_SEND    =>  s_EB_TX_STB                         <= '1';
                                                s_tx_fifo_data         <= s_EB_TX_base_wr_adr;
                                            
                when DATA_SEND              =>  s_tx_fifo_data     <= s_WB_master_i.DAT;
                                                s_EB_TX_STB     <= s_WB_master_i.ACK;
                                        
                                                if(s_WB_master_i.ACK = '1') then
                                                    s_EB_TX_CUR_CYCLE.WR_CNT     <= s_EB_TX_CUR_CYCLE.WR_CNT-1;
                                                end if;
                                                
                when ZERO_PAD_WRITE         =>  s_tx_fifo_data <= (others => '0');
                                                if((s_tx_fifo_am_full = '0') AND (s_eb_tx_zeropad_cnt > 0)) then
                                                    --if(s_tx_fifo_we = '1') then
                                                        s_EB_TX_zeropad_cnt <= s_EB_TX_zeropad_cnt -1;
                                                    --end if;
                                                    s_EB_TX_STB <= '1';
                                                end if;    
                                        
                when ZERO_PAD_WAIT          =>  null;
                
                when others                 =>  null;
            end case;
        end if;
    end if;

end process p_state_output;





end behavioral;
