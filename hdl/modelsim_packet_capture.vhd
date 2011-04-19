library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;

use IEEE.numeric_std.all;



entity bin_file is
end entity bin_file;

architecture sim of bin_file is

constant beef : std_logic_vector(31 downto 0) := x"00000010";



function scramble(slv_arg : std_logic_vector) return integer is
variable result : integer;
variable tmp : std_logic_vector(31 downto 0) := x"00000000";

begin
for i in 0 to 3 loop
	tmp((i+1)*8-1 downto i*8) := slv_arg((4-i)*8-1 downto (3-i)*8);
	result := TO_INTEGER(unsigned(tmp));
end loop;	
return result;
end;


Type pcap_hdr is array (0 to 7) of std_logic_vector (31 downto 0);
constant pcap : pcap_hdr :=(x"D4C3B2A1", x"02000400",
							x"00000000", x"00000000", 
							x"00900100", x"01000000",
							x"197C344D", x"00000000");



type int_file is file of integer; -- 4 bytes each order=4,3,2,1,8,7,6,5...
file my_file : int_file;
type int_array is array(natural range <>) of integer;

function spew(i_arg : integer) return int_array is
variable result : int_array(0 to i_arg+10-1);
begin


for i in 0 to 7 loop
result(i) := scramble(pcap(i));
end loop;
result(8) := i_arg*4; -- scramble(std_logic_vector(to_unsigned(i_arg*4,32)));
result(9) := i_arg*4; --scramble(std_logic_vector(to_unsigned(i_arg*4,32)));

for i in 10 to i_arg+10-1 loop
result(i) := scramble(beef);
end loop;
return result;
end;

constant box_o_ints : int_array := spew(15);
begin -- architecture sim

what : process is
variable my_int_v : integer;
begin
file_open(my_file, "test.pcap", write_mode);
for i in box_o_ints'range loop
write(my_file, box_o_ints(i));

end loop; -- i
file_close(my_file);
file_open(my_file, "my_file.bin", read_mode);
for i in box_o_ints'range loop

-- report integer'image(box_o_ints(i));
read(my_file, my_int_v);
assert my_int_v = box_o_ints(i)
report "read error" severity warning;
end loop; -- i
file_close(my_file);
report("view my_file.bin in emacs hexl-mode") severity failure;
wait;
end process what;

end sim;