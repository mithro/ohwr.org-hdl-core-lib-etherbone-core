library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;

use IEEE.numeric_std.all;

library work;
use work.vhdl_2008_workaround_pkg.all;


entity packet_capture is
generic(filename : string := "123.pcap";  wordsize : natural := 16);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	TOL_i			: in 	std_logic_vector(15 downto 0);
	
	sample_i		: in   	std_logic;
	valid_i			: in   	std_logic;
	data_i			: in	std_logic_vector(wordsize-1 downto 0)
);	
end entity packet_capture;

architecture behavioral of packet_capture is

component binary_sink is
generic(filename : string := "123.pcap";  wordsize : natural := 64; endian : natural := 0);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	rdy_o			: out  	std_logic;

	sample_i		: in   	std_logic;
	valid_i			: in	std_logic;	
	data_i			: in	std_logic_vector(wordsize-1 downto 0)
);	
end component;

type pcap_hdr is array (0 to 7) of std_logic_vector (31 downto 0);
constant pcap : pcap_hdr :=(x"D4C3B2A1", x"02000400",
							x"00000000", x"00000000", 
							x"00900100", x"01000000",
							x"197C344D", x"00000000");



type int_file is file of integer; -- 4 bytes each order=4,3,2,1,8,7,6,5...
type char_file is file of character; -- one byte each
file charinsert : char_file;
file my_file : int_file;


type st is (IDLE, INIT, LISTEN, CLOSE);

signal state 	: st := IDLE;
signal len : integer := 0;
signal rdy : std_logic;
signal sample : std_logic;

begin -- architecture sim

file_sink: binary_sink generic map ( filename => filename,
                                 wordsize =>   wordsize,
                                 endian   =>  0)
                      port map ( clk_i    => clk_i,
                                 nRST_i   => nRST_i,
                                 rdy_o    => rdy,
                                 sample_i => sample,
                                 valid_i  => valid_i,
                                 data_i   => data_i );

 sample <= '1' when sample_i = '1' AND state = LISTEN
 else '0';

what : process is 
variable this : std_logic_vector(31 downto 0);
variable i : integer := 0;
begin
	wait until rising_edge(clk_i);
			case state is
					when IDLE 	=>  if(sample_i = '1') then
										len <= TO_INTEGER(unsigned(TOL_i)); -- subtract preamble bytes
										state <= INIT;
									end if;
					
					when INIT	=>  file_open(charinsert, filename ,write_mode);
									
									for i in 0 to 7 loop
										this := pcap(i);
										write(charinsert, character'val(to_integer(unsigned(this(31 downto 24)))));
										write(charinsert, character'val(to_integer(unsigned(this(23 downto 16)))));
										write(charinsert, character'val(to_integer(unsigned(this(15 downto 8)))));
										write(charinsert, character'val(to_integer(unsigned(this(7 downto 0)))));	
									end loop;
									this := std_logic_vector(unsigned(to_signed(len, 32)));
									write(charinsert, character'val(to_integer(unsigned(this(7 downto 0)))));
									write(charinsert, character'val(to_integer(unsigned(this(15 downto 8)))));
									write(charinsert, character'val(to_integer(unsigned(this(23 downto 16)))));
									write(charinsert, character'val(to_integer(unsigned(this(31 downto 24)))));
									
									write(charinsert, character'val(to_integer(unsigned(this(7 downto 0)))));
									write(charinsert, character'val(to_integer(unsigned(this(15 downto 8)))));
									write(charinsert, character'val(to_integer(unsigned(this(23 downto 16)))));
									write(charinsert, character'val(to_integer(unsigned(this(31 downto 24)))));
									file_close(charinsert);
									len <= len + 2;
									state <= LISTEN;
										
									
					when LISTEN	=> 	if(sample_i = '1' AND LEN > 0) then
										if(valid_i = '1') then
											len <= len - wordsize/8;
										end if;	
									else
										state <= CLOSE;
									end if;
									
									
					when CLOSE	=> 	report("File recorded.") severity warning;
									--state <= IDLE;
					
					when others => 	state <= CLOSE;
				end case;	


end process;

end architecture;

