---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;

entity EBC_main is port
(
   
   clk_i      : in    std_logic;   --! byte clock, trigger on rising edge
   nRST_i     : in    std_logic;   --! reset, assert HI   

   slv16_i    : in std_logic_vector(15 downto 0);
   slv16_o    : out std_logic_vector(15 downto 0);
   we_i : std_logic;
   en_cnt_i   : std_logic                               
);
end EBC_main;


architecture behavioral of EBC_main is
    
signal s_slv16_i,
       s_slv16_o : std_logic_vector(15 downto 0);
       
signal test_hdr : EB_PACK_HDR;

signal cnt_hdr : unsigned(5 downto 0);
alias done : std_logic is cnt_hdr(5);
alias cnt : unsigned(4 downto 0) is cnt_hdr(4 downto 0);


begin

slv16_o <= s_slv16_o;

p_cntr: process (clk_i)
begin
	if rising_edge(clk_i) then
       --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
	   if (nRST_i = '0') then
          cnt_hdr <= "010111"; -- 21 dec
          done <= '0';   
     else
       if(done = '0') then
        if(en_cnt_i = '1') then
          if(we_i = '0') then
            s_slv16_o <= EB_PACK_HDR_TO_SLV16(TO_INTEGER(cnt), test_hdr);
          else
            test_hdr <= SLV16_TO_EB_PACK_HDR(TO_INTEGER(cnt), slv16_i, test_hdr);
          end if;
          cnt_hdr <= cnt_hdr -1; 
        end if;  
       else
        null;
       end if;
          
    end if;
  end if;                                             
end process;


end behavioral; 
       
    
    
    


