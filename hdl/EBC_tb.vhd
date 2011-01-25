library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
USE std.textio.all;
library work;

-------------------------------------------------------------------------------

entity ECB_tb is

end ECB_tb;

-------------------------------------------------------------------------------

architecture TB of ECB_tb is

--

  component main is port
(
   
   clk_i      : in    std_logic;   --! byte clock, trigger on rising edge
   nRST_i     : in    std_logic;   --! reset, assert HI   

   slv16_i    : in std_logic_vector(15 downto 0);
   slv16_o    : out std_logic_vector(15 downto 0);
   we_i : std_logic;
   en_cnt_i   : std_logic                               
);
end component;

  signal CLK      : std_logic;
  signal nRST     : std_logic;
  signal en_cnt   : std_logic;
  signal slv16    : std_logic_vector(15 downto 0);
  signal slv16out : std_logic_vector(15 downto 0);
  signal we       : std_logic; 
  
  signal stop_the_clock : boolean := false;
  constant clock_period: time := 10 ns;
  
  type char_file is file of character;
  file my_file : char_file;
  signal charHi : character;
  signal charLo : character;


  
   
begin  -- TB

  DUT: main
    port map (
        CLK_i            => CLK,
        nRST_I           => nRST,
        slv16_i          => slv16, 
        slv16_o          => slv16out,
        we_i             =>  we,
        en_cnt_i         => en_cnt);

charHi <= character'val(TO_INTEGER(unsigned(slv16out(15 downto 8))));
charLo <= character'val(TO_INTEGER(unsigned(slv16out(7 downto 0))));

clocking: process
  begin
    while not stop_the_clock loop
      CLK <= '0', '1' after clock_period / 2;
      wait for clock_period;
      
    end loop;
    wait;
  end process;


stimuli: process


    begin       
        slv16   <= x"BEEF";
        nRST     <=  '0';
        en_cnt  <= '0';
        we <= '1';
        wait for clock_period*2;
        nRST     <=  '1';
        wait for clock_period;
        en_cnt <= '1';
        wait for clock_period*30;
        en_cnt <= '0';
        nRST   <= '0';
        we     <= '0';
        wait for clock_period;
        
        nRST   <= '1';
        wait for clock_period;
        en_cnt <= '1';
        wait for clock_period;
        
        file_open(my_file, "my_file.bin", write_mode);
        for i in 1 to 30 loop
          
        write(my_file, charHi);
        write(my_file, charLo);
        
        wait for clock_period;
        end loop; 
        
        file_close(my_file);
        wait for clock_period;
        stop_the_clock <= true;
end process;

end TB;
