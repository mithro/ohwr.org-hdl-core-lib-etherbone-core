--! @file WB_bus_adapter_streaming_sg.vhd
--! @brief WB adapters
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
--------------------------------------------------------------------------------

---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.vhdl_2008_workaround_pkg.all;

entity WB_bus_adapter_streaming_sg is
generic(g_adr_width_A : natural := 16; g_adr_width_B  : natural := 32;
		g_dat_width_A : natural := 16; g_dat_width_B  : natural := 32;
		g_pipeline : natural := 2 
		);
		-- pipeline: 0 => A-x, 1 x-B, 2 A-B 
port(
		clk_i		: in std_logic;
		nRst_i		: in std_logic;
		
		A_CYC_i		: in std_logic;
		A_STB_i		: in std_logic;
		A_ADR_i		: in std_logic_vector(g_adr_width_A-1 downto 0);
		A_SEL_i		: in std_logic_vector(g_dat_width_A/8-1 downto 0);
		A_WE_i		: in std_logic;
		A_DAT_i		: in std_logic_vector(g_dat_width_A-1 downto 0);
		A_ACK_o		: out std_logic;
		A_ERR_o		: out std_logic;
		A_RTY_o		: out std_logic;
		A_STALL_o	: out std_logic;
		A_DAT_o		: out std_logic_vector(g_dat_width_A-1 downto 0);
		
		
		B_CYC_o		: out std_logic;
		B_STB_o		: out std_logic;
		B_ADR_o		: out std_logic_vector(g_adr_width_B-1 downto 0);
		B_SEL_o		: out std_logic_vector(g_dat_width_B/8-1 downto 0);
		B_WE_o		: out std_logic;
		B_DAT_o		: out std_logic_vector(g_dat_width_B-1 downto 0);
		B_ACK_i		: in std_logic;
		B_ERR_i		: in std_logic;
		B_RTY_i		: in std_logic;
		B_STALL_i	: in std_logic;
		B_DAT_i		: in std_logic_vector(g_dat_width_B-1 downto 0)

);
end WB_bus_adapter_streaming_sg;




architecture behavioral of WB_bus_adapter_streaming_sg is

	constant c_adr_w_max : natural := maximum(g_adr_width_A, g_adr_width_B);
	constant c_dat_w_max : natural := maximum(g_dat_width_A, g_dat_width_B);
	constant c_sel_w_max : natural := maximum(g_dat_width_A, g_dat_width_B)/8;
	constant c_adr_w_min : natural := minimum(g_adr_width_A, g_adr_width_B);
	constant c_dat_w_min : natural := minimum(g_dat_width_A, g_dat_width_B);
	constant c_sel_w_min : natural := minimum(g_dat_width_A, g_dat_width_B)/8;
	
	signal sipo_d	 : std_logic_vector(c_dat_w_min-1 downto 0);
	signal sipo_q	 : std_logic_vector(c_dat_w_max-1 downto 0);
	signal piso_d	 : std_logic_vector(c_dat_w_max-1 downto 0);
	signal piso_q	 : std_logic_vector(c_dat_w_min-1 downto 0);
	
	-- direct adapter signals
	constant c_adr_pad 	: std_logic_vector(c_adr_w_max-1 downto 0) 	:=  (others => '0');
	constant c_sel_pad 	: std_logic_vector(c_sel_w_max-1 downto 0) 	:=  (others => '0');
	constant c_dat_pad 	: std_logic_vector(c_dat_w_max-1 downto 0) 	:=  (others => '0');
	
	signal 	adr 		: std_logic_vector(c_adr_w_max-1 downto 0);
	signal 	slave_dat 	: std_logic_vector(c_dat_w_max-1 downto 0);
	signal 	master_dat 	: std_logic_vector(c_dat_w_max-1 downto 0);
	signal 	sel 		: std_logic_vector(c_sel_w_max-1 downto 0);
	signal  cyc : std_logic;
	
	-- S/G adapter signals
	signal sipo_sh_in 	: std_logic;
	signal sipo_clr 	: std_logic;
	signal sipo_full 	: std_logic;
	

	signal piso_sh_out 	: std_logic;
	signal piso_ld 	: std_logic;
	signal piso_empty 	: std_logic;
	signal piso_am_empty	:std_logic;
	signal piso_full : std_logic;
	signal ld 	: std_logic;
	
	signal get_adr : std_logic;
	signal B_STB : std_logic;
	signal ALLRDY_STROBED : std_logic;
		
	component sipo_flag is
	generic(g_width_IN : natural := 16; g_width_OUT  : natural := 32); 
	port(
			clk_i				: in std_logic;
			nRst_i				: in std_logic;
			
			d_i					: in std_logic_vector(g_width_IN-1 downto 0);
			en_i				: in std_logic;
			clr_i				: in std_logic;
			
			q_o					: out std_logic_vector(g_width_OUT-1 downto 0);
			full_o				: out std_logic

	);
	end component;
	
	component piso_flag is
generic(g_width_IN : natural := 16; g_width_OUT  : natural := 32); 
	port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		d_i					: in std_logic_vector(g_width_IN-1 downto 0);
		en_i				: in std_logic;
		ld_i				: in std_logic;
		
		q_o					: out std_logic_vector(g_width_OUT-1 downto 0);
		
		full_o				: out std_logic;
		almost_empty_o		: out std_logic;
		empty_o				: out std_logic

);
end component;

begin

assert not (g_dat_width_A = g_dat_width_B) report "WB streaming adapter superfluous, IO data widths are identical." severity error; 
	
---------------------------------------------------------------------------------------------------------------------------------	
PIPELINED:		if(g_pipeline > 0) GENERATE		
		
A_LESSER_B:		if(c_dat_w_min = g_dat_width_A) GENERATE
	
			gather : sipo_flag -- MA ->-> => MB
			generic map(g_width_IN => c_dat_w_min, g_width_OUT  => c_dat_w_max) 
			port map(
			clk_i		=> clk_i,
			nRst_i	=> nRSt_i,
			
			d_i			=> sipo_d,
			en_i		=> sipo_sh_in,
			clr_i		=> sipo_clr,
			
			q_o			=> sipo_q,
			full_o		=> sipo_full
			);
			
			--for(i

			A_DAT_o <= (others => '0');
			A_ERR_o	 <= B_ERR_i;
			A_RTY_o	 <= B_RTY_i;
			
			B_WE_o <= A_WE_i;
					
			A_STALL_o <= '1' when sipo_full ='1' AND B_STALL_i = '1'
			else '0';
			
			sipo_sh_in <= '1' when (NOT(sipo_full = '1' AND B_STALL_i = '1') AND A_CYC_i = '1' AND A_STB_i = '1')
			else '0';  
			
			B_CYC_o <= '1' when (A_CYC_i = '1' OR sipo_full= '1')
			else '0';
			
			
			
			
			B_STB_o <= B_STB; 
			B_STB <= sipo_full AND NOT ALLRDY_STROBED;
	
			sipo_d <= A_DAT_i;
			B_DAT_o <= sipo_q;
			
			process (clk_i)
			begin
				if (clk_i'event and clk_i = '1') then
					if(nRSt_i = '0') then
						
						A_ACK_o 	<= '0';
						ALLRDY_STROBED <= '0';
					
					else
						
						
						if(sipo_full = '1') then
							if(B_STALL_i = '0') then
								ALLRDY_STROBED <= '1';
							end if;
						else
							ALLRDY_STROBED <= '0';
						end if;
						
						------- TODO
						if(A_STB_i = '1' AND NOT (sipo_full ='1' AND B_STALL_i = '1')) then
						  A_ACK_o 	<= '1';
						else   
						  A_ACK_o 	<= '0';
						end if;
						
					end if;	
				end if;
			end process;
				
		END GENERATE;
		
		--scatter
A_GREATER_B:				if(c_dat_w_max = g_dat_width_A) GENERATE
			
			
			scatter : piso_flag -- SB => ->-> SA 
			generic map(g_width_IN => c_dat_w_max, g_width_OUT  => c_dat_w_min) 
			port map(
			clk_i		=> clk_i,
			nRst_i		=> nRSt_i,
			
			d_i			=> piso_d,
			en_i		=> piso_sh_out,
			ld_i		=> piso_ld,
			
			q_o			=> piso_q,
			full_o		=>	piso_full,
			almost_empty_o	=> piso_am_empty,
			empty_o		=> piso_empty
			);
		
			A_DAT_o <= (others => '0');
			piso_d	<= 	A_DAT_i;
			B_DAT_o <=  piso_q;
			A_ERR_o	 <= B_ERR_i;
			A_RTY_o	 <= B_RTY_i;
			B_WE_o <= A_WE_i;
				
			piso_ld <= '1' when A_CYC_i = '1' AND A_STB_i = '1' AND (piso_empty = '1' OR (piso_am_empty ='1' AND B_STALL_i = '0'))
			else '0';
			
			piso_sh_out <= '1' when B_STALL_i = '0' AND piso_empty = '0'
			else '0';
			
			B_CYC_o <= '1' when (A_CYC_i = '1' OR piso_empty = '0')
			else '0';
			
								
			B_STB_o <= '1' when (piso_empty = '0') 
			else '0';

			A_STALL_o <= '1' when NOT (piso_empty = '1' OR (piso_am_empty ='1' AND B_STALL_i = '0'))
			else '0';
			
			
			process (clk_i)
			begin
				if (clk_i'event and clk_i = '1') then
					if(nRSt_i = '0') then
						A_ACK_o <= '0';
					else
						if(A_STB_i = '1' AND (piso_empty = '1' OR (piso_am_empty ='1' AND B_STALL_i = '0') )) then
							A_ACK_o 	<= '1';
						else 
						  A_ACK_o 	<= '0';	
					  end if;	
				end if;
			end if;	
			end process;
		end GENERATE; -- A_width < BA_width
end GENERATE; --pipeline A-B	
end architecture;
