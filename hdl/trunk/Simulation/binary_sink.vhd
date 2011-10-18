library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;

use IEEE.numeric_std.all;

library work;
use work.vhdl_2008_workaround_pkg.all;


entity binary_sink is
generic(filename : string := "123.pcap";  wordsize : natural := 64; endian : natural := 0);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	
	rdy_o			: out  	std_logic;

	sample_i		: in   	std_logic;
	valid_i			: in	std_logic;	
	data_i			: in	std_logic_vector(wordsize-1 downto 0)
);	
end entity binary_sink;

architecture behavioral of binary_sink is

type char_file is file of character; -- one byte each
file charinsert : char_file;



type st is (IDLE, LISTEN, CLOSE);

--signal state 	: st := IDLE;
signal rdy : std_logic := '0';
begin -- architecture sim

assert (wordsize = (2**ld(wordsize))) 
report("BAD WORSIZE: " &  integer'image(wordsize) & " is not a power of 2") severity failure;

assert ((endian = 0) OR (endian = 1)) 
report("BAD ENDIANESS: 0 big endian, 1 little endian") severity failure;

rdy_o <= rdy AND sample_i;


what : process is 

variable state : st := IDLE;

begin

	wait until rising_edge(clk_i);
			if(nRST_i ='0') then
				state := CLOSE;
			end if;	
				if( state = IDLE) then
					if(sample_i = '1') then
						file_open(charinsert, filename ,append_mode);
						rdy <= '1';
						state := LISTEN;
						report("File " & filename & " opened for write" ) severity note;
					end if;
				end if;	
				
				if(state = LISTEN) then
					if(sample_i = '1') then
						if(valid_i = '1') then
							if(endian = 0) then					
								for G in wordsize/8 downto 1 loop
									write(charinsert, character'val(to_integer(unsigned(data_i(G*8-1 downto (G-1)*8)))));
								end loop;
							else
								for G in 1 to wordsize/8 loop
									write(charinsert, character'val(to_integer(unsigned(data_i(G*8-1 downto (G-1)*8)))));
								end loop;	
							end if;
						end if;
					else
						state := CLOSE;
					end if;
				end if;
									
				if(state = CLOSE) then
					file_close(charinsert);
					report("File " & filename & " closed." ) severity note;
					rdy <= '0';
					state := IDLE;
				end if;


end process;

end architecture;

