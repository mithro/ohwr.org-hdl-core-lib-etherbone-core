--! @file eb_master_wb_if.vhd
--! @brief Ctrl wishbone interface for the EtherBone master
--!
--! Copyright (C) 2013-2014 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
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
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.eb_hdr_pkg.all;

entity eb_master_wb_if is
generic(g_adr_bits_hi : natural := 8);
port(
  clk_i       : in  std_logic;
  rst_n_i     : in  std_logic;

  clear_o     : out std_logic;
  flush_o     : out std_logic;

  slave_i     : in  t_wishbone_slave_in;
  slave_dat_o : out t_wishbone_data;
  slave_ack_o : out  std_logic;
  slave_err_o : out  std_logic;
  
  my_mac_o    : out std_logic_vector(47 downto 0);
  my_ip_o     : out std_logic_vector(31 downto 0);
  my_port_o   : out std_logic_vector(15 downto 0);
  
  his_mac_o   : out std_logic_vector(47 downto 0); 
  his_ip_o    : out std_logic_vector(31 downto 0);
  his_port_o  : out std_logic_vector(15 downto 0); 
  length_o    : out unsigned(15 downto 0);
  max_ops_o   : out unsigned(15 downto 0);
  adr_hi_o    : out std_logic_vector(g_adr_bits_hi-1 downto 0);
  eb_opt_o    : out t_rec_hdr);
end eb_master_wb_if;


architecture rtl of  eb_master_wb_if is

   --Register map
   constant c_CLEAR        : natural := 0;                 --wo    00
   constant c_FLUSH        : natural := c_CLEAR        +4; --wo    04
   constant c_STATUS       : natural := c_FLUSH        +4; --rw    08
   constant c_SRC_MAC_HI   : natural := c_STATUS       +4; --rw    0C
   constant c_SRC_MAC_LO   : natural := c_SRC_MAC_HI   +4; --rw    10 
   constant c_SRC_IPV4     : natural := c_SRC_MAC_LO   +4; --rw    14 
   constant c_SRC_UDP_PORT : natural := c_SRC_IPV4     +4; --rw    18
   constant c_DST_MAC_HI   : natural := c_SRC_UDP_PORT +4; --rw    1C
   constant c_DST_MAC_LO   : natural := c_DST_MAC_HI   +4; --rw    20
   constant c_DST_IPV4     : natural := c_DST_MAC_LO   +4; --rw    24
   constant c_DST_UDP_PORT : natural := c_DST_IPV4     +4; --rw    28
   constant c_PAC_LEN      : natural := c_DST_UDP_PORT +4; --rw    2C
   constant c_ADR_HI       : natural := c_PAC_LEN      +4; --rw    30
   constant c_OPS_MAX      : natural := c_ADR_HI       +4; --rw    34
   constant c_EB_OPT       : natural := c_OPS_MAX      +4; --rw    40

   constant c_STAT_CONFIGURED  : t_wishbone_data := x"00000001";
   constant c_STAT_BUSY        : t_wishbone_data := x"00000002";
   constant c_STAT_ERROR       : t_wishbone_data := x"00000004";
   constant c_STAT_EB_SENT     : t_wishbone_data := x"FFFF0000";

   signal   r_slave_out_ack,
            r_slave_out_err : std_logic;
            
            
   signal   r_slave_out_dat : std_logic_vector(31 downto 0);       
   
   signal   r_stat         : std_logic_vector(0 downto 0);
   signal   r_clr          : std_logic_vector(0 downto 0);
   signal   r_flush        : std_logic_vector(0 downto 0);
   signal   r_his_mac, 
            r_my_mac       : std_logic_vector(6*8-1 downto 0);
   alias    a_his_mac_hi   : std_logic_vector(31 downto 0) is r_his_mac(r_his_mac'left downto 16);
   alias    a_his_mac_lo   : std_logic_vector(15 downto 0) is r_his_mac(15 downto 0);         
   alias    a_my_mac_hi    : std_logic_vector(31 downto 0) is r_my_mac(r_my_mac'left downto 16);
   alias    a_my_mac_lo    : std_logic_vector(15 downto 0) is r_my_mac(15 downto 0);          
   signal   r_his_ip, 
            r_my_ip        : std_logic_vector(4*8-1 downto 0);         
   signal   r_his_port, 
            r_my_port      : std_logic_vector(2*8-1 downto 0); 
            
   signal   r_ops_max      : std_logic_vector(15 downto 0);         
   signal   r_length       : std_logic_vector(15 downto 0);
   signal   r_adr_hi       : std_logic_vector(g_adr_bits_hi-1 downto 0);
   signal   r_eb_opt       : std_logic_vector(31 downto 0);

   constant c_dat_bit : natural := 31-g_adr_bits_hi+2;

   constant c_EB_PORT : std_logic_vector(15 downto 0) := x"EBD0"; 

begin

   --CTRL REGs
   clear_o  <= r_clr(0);
   flush_o     <= r_flush(0);
   his_mac_o   <= r_his_mac;
   his_ip_o    <= r_his_ip;
   his_port_o  <= r_his_port;
   my_mac_o    <= r_my_mac;
   my_ip_o     <= r_my_ip;
   my_port_o   <= r_my_port;
   max_ops_o   <= unsigned(r_ops_max);
   length_o    <= unsigned(r_length);
   adr_hi_o    <= r_adr_hi;
   eb_opt_o    <= f_parse_rec(r_eb_opt);

	slave_dat_o <= r_slave_out_dat;
	slave_ack_o <= r_slave_out_ack;
	slave_err_o <= r_slave_out_err;

   p_wb_if : process (clk_i) is
      variable v_dat_i  : t_wishbone_data;
      variable v_dat_o  : t_wishbone_data;
      variable v_adr    : natural; 
      variable v_sel    : t_wishbone_byte_select;
      variable v_we     : std_logic;
      variable v_en     : std_logic; 

   begin
      if rising_edge(clk_i) then
         if rst_n_i = '0' then
            r_clr       <= (others => '0');
            r_flush     <= (others => '0');
            r_eb_opt    <= (others => '0');
            r_length    <= std_logic_vector(to_unsigned(1500, r_length'length));
            r_my_mac    <= x"D15EA5EDBABE";
            r_my_ip     <= x"DEADBEEF";
            r_my_port   <= c_EB_PORT;
            r_his_mac   <= (others => '1');
            r_his_ip    <= (others => '1');
            r_his_port  <= c_EB_PORT; 
         else
            -- short names  
            v_dat_i := slave_i.dat;
            v_adr   := to_integer(unsigned(slave_i.adr(7 downto 2)) & "00");
            v_sel   := slave_i.sel;
            v_en    := slave_i.cyc and slave_i.stb;
            v_we    := slave_i.we; 
               
            --interface outputs
            r_slave_out_ack    <= '0';
            r_slave_out_err    <= '0';
            r_slave_out_dat    <= (others => '0');

            r_clr       <= (others => '0');
            r_flush     <= (others => '0');    
    
            if(v_en = '1') then
               r_slave_out_ack <= '1'; -- ack is default, we'll change it if an error occurs
               --if(v_adr(c_dat_bit) = '0') then
                  -- control registers
                  if(v_we = '1') then            
                     case v_adr is
                        when c_CLEAR          => r_clr         <= f_wb_wr(r_clr,          v_dat_i, v_sel, "set"); 
                        when c_FLUSH          => r_flush       <= f_wb_wr(r_flush,        v_dat_i, v_sel, "set"); 
                        when c_SRC_MAC_HI     => a_my_mac_hi   <= f_wb_wr(a_my_mac_hi,    v_dat_i, v_sel, "owr");
                        when c_SRC_MAC_LO     => a_my_mac_lo   <= f_wb_wr(a_my_mac_lo,    v_dat_i, v_sel, "owr");
                        when c_SRC_IPV4       => r_my_ip       <= f_wb_wr(r_my_ip,        v_dat_i, v_sel, "owr");
                        when c_SRC_UDP_PORT   => r_my_port     <= f_wb_wr(r_my_port,      v_dat_i, v_sel, "owr");
                        when c_DST_MAC_HI     => a_his_mac_hi  <= f_wb_wr(a_his_mac_hi,   v_dat_i, v_sel, "owr");
                        when c_DST_MAC_LO     => a_his_mac_lo  <= f_wb_wr(a_his_mac_lo,   v_dat_i, v_sel, "owr");
                        when c_DST_IPV4       => r_his_ip      <= f_wb_wr(r_his_ip,       v_dat_i, v_sel, "owr");
                        when c_DST_UDP_PORT   => r_his_port    <= f_wb_wr(r_his_port,     v_dat_i, v_sel, "owr");
                        when c_PAC_LEN        => r_length      <= f_wb_wr(r_length,       v_dat_i, v_sel, "owr"); 
                        when c_ADR_HI         => r_adr_hi      <= v_dat_i(v_dat_i'left downto v_dat_i'length - r_adr_hi'length); 
                        when c_OPS_MAX        => r_ops_max     <= f_wb_wr(r_ops_max,      v_dat_i, v_sel, "owr"); 
                        when c_EB_OPT         => r_eb_opt      <= f_wb_wr(r_eb_opt,       v_dat_i, v_sel, "owr");
                        when others => r_slave_out_ack  <= '0'; r_slave_out_err <= '1';
                     end case;
                  else  
                     case v_adr is
                        when c_STATUS           => r_slave_out_dat(r_stat'range)       <= r_stat;
                        when c_SRC_MAC_HI       => r_slave_out_dat(a_my_mac_hi'range)  <= a_my_mac_hi;
                        when c_SRC_MAC_LO       => r_slave_out_dat(a_my_mac_lo'range)  <= a_my_mac_lo;
                        when c_SRC_IPV4         => r_slave_out_dat(r_my_ip'range)      <= r_my_ip;
                        when c_SRC_UDP_PORT     => r_slave_out_dat(r_my_port'range)    <= r_my_port;
                        when c_DST_MAC_HI       => r_slave_out_dat(a_his_mac_hi'range) <= a_his_mac_hi;
                        when c_DST_MAC_LO       => r_slave_out_dat(a_his_mac_lo'range) <= a_his_mac_lo;
                        when c_DST_IPV4         => r_slave_out_dat(r_his_ip'range)     <= r_his_ip;
                        when c_DST_UDP_PORT     => r_slave_out_dat(r_his_port'range)   <= r_his_port;
                        when c_PAC_LEN          => r_slave_out_dat(r_length'range)     <= r_length; 
                        when c_ADR_HI           => r_slave_out_dat(r_slave_out_dat'left downto r_slave_out_dat'length - r_adr_hi'length)     <= r_adr_hi; 
                        when c_OPS_MAX          => r_slave_out_dat(r_ops_max'range)    <= r_ops_max; 
                        when c_EB_OPT           => r_slave_out_dat(r_eb_opt'range)     <= r_eb_opt; 
                        when others => r_slave_out_ack  <= '0'; r_slave_out_err <= '1';
                     end case;    
                  end if; -- we
           --    else
                  --STAGING AREA 
           --       if(v_we = '0') then   
           --          r_slave_out_ack  <= '0'; r_slave_out_err <= '1'; -- a read on the framer is forbidden, give the user a scolding
           --       end if;
           --    end if; -- dat_bit  
            end if; -- en
         end if; -- rstn
      end if; -- clk edge
   end process;

end architecture;
