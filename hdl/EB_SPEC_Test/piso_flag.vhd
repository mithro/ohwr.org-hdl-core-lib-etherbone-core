--! @file piso_flag.vhd
--! @brief Parallel-In-Serial-Out shiftregister with flags
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

entity piso_flag is
generic(g_width_IN : natural := 16; g_width_OUT  : natural := 32; g_protected : natural := 1); 
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
end piso_flag;




architecture behavioral of piso_flag is

signal		sh_cnt	: unsigned(8 downto 0);
alias 		empty : std_logic is sh_cnt(sh_cnt'LEFT);

signal 		sh_reg : std_logic_vector(g_width_in -1 downto 0);
constant  	zero_insert : std_logic_vector(g_width_out-1 downto 0) := (others => '0');
signal 		full : std_logic;

  begin

g_prot : if(g_protected = 1) generate


almost_empty_o <= '1' when sh_cnt = to_unsigned(0, 9)
				else '0';
q_o 	<= sh_reg(sh_reg'left downto sh_reg'length-q_o'length);
empty_o <= empty;
full_o 	<= full;

  -- Your VHDL code defining the model goes here
  process (clk_i)
  begin
  	if (clk_i'event and clk_i = '1') then
  		if(nRSt_i = '0') then
			full <= '0';
			sh_cnt 	<= (others => '1'); 
			
		else
			if(ld_i = '1' AND full = '0') then
				full 	<= '1';
				sh_cnt	<= to_unsigned((g_width_IN/g_width_OUT)-1,9); 
			  sh_reg <= d_i; 
			elsif(en_i = '1' AND empty = '0') then
				full <= '0';
				sh_cnt <= sh_cnt-1;
				sh_reg <= sh_reg(g_width_in - g_width_out -1 downto 0) & zero_insert;
			end if;	
		end if;	
  	end if;
  end process;
  
end generate;
  

g_unprot : if(g_protected = 0) generate

almost_empty_o <= '1' when sh_cnt = to_unsigned(0, 9)
				else '0';
q_o 	<= sh_reg(sh_reg'left downto sh_reg'length-q_o'length);
empty_o <= empty;
full_o 	<= full;

  -- Your VHDL code defining the model goes here
  process (clk_i)
  begin
  	if (clk_i'event and clk_i = '1') then
  		if(nRSt_i = '0') then
			full <= '0';
			sh_cnt 	<= (others => '1'); 
			
		else
			if(ld_i = '1') then
				full 	<= '1';
				sh_cnt	<= to_unsigned((g_width_IN/g_width_OUT)-1,9); 
			  sh_reg <= d_i; 
			elsif(en_i = '1') then
				full <= '0';
				sh_cnt <= sh_cnt-1;
				sh_reg <= sh_reg(g_width_in - g_width_out -1 downto 0) & zero_insert;
			end if;	
		end if;	
  	end if;
  end process;
  
end generate;



  
end behavioral;
