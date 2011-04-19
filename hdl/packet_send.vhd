library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;

use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;


entity packet_capture is
generic(filename : string := "123.pcap" );
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	TOL_o			: in 	std_logic_vector(15 downto 0);
	
	send_i		: in   	std_logic;
	
	stall_i		: in   	std_logic;
	valid_o			: out   	std_logic;
	data_o			: out	std_logic_vector(31 downto 0)
);	
end entity packet_capture;

architecture behavioral of packet_capture is






function reorder(slv_arg : std_logic_vector) return integer is
variable result : integer;
variable tmp : std_logic_vector(31 downto 0) := x"00000000";

begin
for i in 0 to 3 loop
	tmp((i+1)*8-1 downto i*8) := slv_arg((4-i)*8-1 downto (3-i)*8);
	result := TO_INTEGER(unsigned(tmp));
end loop;	
return result;
end;


type pcap_hdr is array (0 to 7) of std_logic_vector (31 downto 0);
constant pcap : pcap_hdr :=(x"D4C3B2A1", x"02000400",
							x"00000000", x"00000000", 
							x"00900100", x"01000000",
							x"197C344D", x"00000000");



type int_file is file of integer; -- 4 bytes each order=4,3,2,1,8,7,6,5...

file my_file : int_file;



type st is (IDLE, INIT, LISTEN, CLOSE);

signal state 	: st := IDLE;

signal len : natural := 0;


begin -- architecture sim

what : process is 
begin
	wait until rising_edge(clk_i);
			case state is
					when IDLE 	=>  if(sample_i = '1') then
										len <= TO_INTEGER(unsigned(TOL_i)+16); -- subtract preamble bytes
										state <= INIT;
									end if;
					
					when INIT	=>  file_open(my_file, filename , write_mode);
									for i in 0 to 7 loop
										write(my_file, reorder(pcap(i)));
									end loop;
									write(my_file,  len); -- section size
									write(my_file,  len); 
									state <= LISTEN;
									
					when LISTEN	=> 	if(sample_i = '1' AND LEN > 0) then
										if(valid_i = '1') then
											if(NOT (data_i = c_PREAMBLE(63 downto 32) OR data_i = c_PREAMBLE(31 downto 0))) then
												write(my_file, reorder(data_i));
												len <= len -4;
											end if;
										end if;
									else
										state <= CLOSE;
									end if;
									
					when CLOSE	=> 	file_close(my_file);
									report("File recorded.") severity warning;
									--state <= IDLE;
					
					when others => 	state <= CLOSE;
				end case;	


end process;

end architecture;

