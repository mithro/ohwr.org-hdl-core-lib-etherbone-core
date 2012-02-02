--! @file packet_source.vhd
--! @brief Streams network packages on a 16b WB interface
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

library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;

use IEEE.numeric_std.all;

library work;
use work.vhdl_2008_workaround_pkg.all;


entity packet_source is
generic(filename : string := "123.pcap";  wordsize : natural := 16; endian : natural := 0);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	
	rdy_o			: out  	std_logic;

	run_i			: in   	std_logic;
	request_i		: in 	std_logic;
	valid_o			: out	std_logic;	
	data_o			: out	std_logic_vector(wordsize-1 downto 0)
);	
end entity packet_source;

architecture behavioral of packet_source is

type char_file is file of character; -- one byte each
file charread : char_file;



type st is (IDLE, TALK, CLOSE, WAITING);

signal state 	: st := IDLE;
signal rdy : std_logic := '0';
signal data : std_logic_vector(wordsize-1 downto 0);
signal valid : std_logic := '0'; 

begin -- architecture sim

assert (wordsize = (2**ld(wordsize))) 
report("BAD WORSIZE: " &  integer'image(wordsize) & " is not a power of 2") severity failure;

assert ((endian = 0) OR (endian = 1)) 
report("BAD ENDIANESS: 0 big endian, 1 little endian") severity failure;

rdy_o <= rdy;
data_o <= data;
valid_o <= '1' when valid  = '1' AND state = TALK
else '0';

what : process is 
variable tmp_data : character := 'A';
begin

	wait until rising_edge(clk_i);
			case state is
					when IDLE 	=>  if(run_i = '1') then
										file_open(charread, filename ,read_mode);
										
										rdy <= '1';
										state <= TALK;
										report("File " & filename & " opened for read" ) severity note;
										
										--skip pcap hdr
										for i in 0 to 39 loop
											if(NOT ENDFILE(charread)) then
												read(charread, tmp_data);
											else
												state <= CLOSE;
												rdy <= '0';
											end if;
										end loop;		
									end if;
					
					when TALK	=> 	if(run_i = '1' AND (NOT ENDFILE(charread))) then
										valid <= '0';
										if(request_i = '1') then
											if(endian = 0) then					
												for G in wordsize/8 downto 1 loop
													if(NOT ENDFILE(charread)) then
															read(charread, tmp_data);
														data(G*8-1 downto (G-1)*8) <= std_logic_vector(to_unsigned(character'pos(tmp_data), 8));
													else
														data(G*8-1 downto (G-1)*8) <= (others =>'0');
													end if;		
												end loop;
											else
												for G in 1 to wordsize/8 loop
													if(NOT ENDFILE(charread)) then
														read(charread, tmp_data);
														data(G*8-1 downto (G-1)*8) <= std_logic_vector(to_unsigned(character'pos(tmp_data), 8));
													else
														read(charread, tmp_data);
														data(G*8-1 downto (G-1)*8) <= (others =>'0');
													end if;	
												end loop;	
											end if;
											valid <= '1';
										end if;
									else
										valid <= '0';
										state <= CLOSE;
										rdy <= '0';
									end if;
									
					when CLOSE	=> 	file_close(charread);
									report("File " & filename & " closed." ) severity note;
									state <= WAITING;
					
					when WAITING => if(run_i = '0') then 
										state <= IDLE;
									end if;	
					
					when others => 	state <= CLOSE;
				end case;	


end process;

end architecture;

