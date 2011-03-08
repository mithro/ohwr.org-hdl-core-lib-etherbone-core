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

component piso_sreg_gen is 
generic(g_width_in : natural := 160; g_width_out : natural := 16);
 port(
        d_i        : in    std_logic_vector(g_width_in -1 downto 0);        --parallel in
        q_o        : out    std_logic_vector(g_width_out -1 downto 0);        --serial out
        clk_i    : in    std_logic;                                        --clock
        nRST_i    : in     std_logic;
        en_i    : in     std_logic;                                        --shift enable        
        ld_i    : in     std_logic                                        --parallel load                                
    );
    end component;
    

    

    
 
signal s_slv16_o : std_logic_vector(15 downto 0);
       
signal test0_hdr : IPV4_HDR;
signal test1_hdr : UDP_HDR;
signal test2_hdr : EB_HDR;

signal en, ld : std_logic;

signal p_in, s_in : std_logic_vector((160+64+96)-1 downto 0);
 

begin
-- 000 >>Eb - UDP - IP >>
p_in <= TO_STD_LOGIC_VECTOR(test2_hdr) & TO_STD_LOGIC_VECTOR(test1_hdr) & TO_STD_LOGIC_VECTOR(test0_hdr);


shift_out : piso_sreg_gen
generic map (160+64+96, 16) -- size is IPV4+UDP+EB
port map (

        clk_i  => clk_i,                                        --clock
        nRST_i => nRST_i,
        en_i   => en,                        --shift enable        
        ld_i   => ld,                            --parallel load
        d_i    => p_in,        --parallel in
        q_o    => s_slv16_o                            --serial out
);



slv16_o <= s_slv16_o;

p_cntr: process (clk_i)
begin
    if rising_edge(clk_i) then
       --==========================================================================
       -- SYNC RESET                         
       --========================================================================== 
       if (nRST_i = '0') then
        test0_hdr <= INIT_IPV4_HDR(x"C0A80001");
        test1_hdr <= INIT_UDP_HDR;
        test2_hdr <= INIT_EB_HDR;
        ld <= '1';    
     else
        if(en_cnt_i = '1') then
          ld <= '0';
          en <= '1';        
        end if;  
     end if;
  end if;                                             
end process;


end behavioral; 
       
    
    
    


