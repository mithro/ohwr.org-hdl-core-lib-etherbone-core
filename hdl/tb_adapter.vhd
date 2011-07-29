library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;
use ieee.math_real.all; -- for UNIFORM, TRUNC
use ieee.numeric_std.all; -- for TO_UNSIGNED

use work.vhdl_2008_workaround_pkg.all;


entity tb_adapter is
end;

architecture bench of tb_adapter is

  component WB_bus_adapter_streaming_sg
  generic(g_adr_width_A : natural := 32; g_adr_width_B  : natural := 32;
  		g_dat_width_A : natural := 32; g_dat_width_B  : natural := 16;
  		g_pipeline : natural 
  		);
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
  end component;

  constant c_adr_width_A : natural := 32;
  constant c_dat_width_A : natural := 16;
  constant c_adr_width_B : natural := 32;
  constant c_dat_width_B : natural := 32;
  
  constant num		 : natural := 32;

  
  
  subtype word_A is std_logic_vector(c_dat_width_A -1 downto 0);
  subtype word_B is std_logic_vector(c_dat_width_B -1 downto 0);

  
  --type 	A_adr	 is array (0 to numWRs-1) of word_A;
  type 	A_val	 is array (0 to num-1) of word_A;
  type 	B_val	 is array (0 to maximum(c_dat_width_A, c_dat_width_B)/minimum(c_dat_width_A, c_dat_width_B)*num-1) of word_B;
  
	function genA (num : integer)
	return A_val is
		variable i : integer := 0;
		variable result : A_val;
		
	begin
	
		for i in result'RANGE loop
			result(i) := word_A(to_unsigned(num-i, c_dat_width_A));
		end loop;
		return result;
	end function;	
  
  
  signal clk_i: std_logic;
  signal nRst_i: std_logic;
  signal A_CYC_i: std_logic;
  signal A_STB_i: std_logic;
  signal A_ADR_i: std_logic_vector(c_adr_width_A-1 downto 0);
  signal A_SEL_i: std_logic_vector(c_dat_width_A/8-1 downto 0);
  signal A_WE_i: std_logic;
  signal A_DAT_i: std_logic_vector(c_dat_width_A-1 downto 0);
  signal A_ACK_o: std_logic;
  signal A_ERR_o: std_logic;
  signal A_RTY_o: std_logic;
  signal A_STALL_o: std_logic;
  signal A_DAT_o: std_logic_vector(c_dat_width_A-1 downto 0);
  signal B_CYC_o: std_logic;
  signal B_STB_o: std_logic;
  signal B_ADR_o: std_logic_vector(c_adr_width_B-1 downto 0);
  signal B_SEL_o: std_logic_vector(c_dat_width_B/8-1 downto 0);
  signal B_WE_o: std_logic;
  signal B_DAT_o: std_logic_vector(c_dat_width_B-1 downto 0);
  signal B_ACK_i: std_logic;
  signal B_ERR_i: std_logic;
  signal B_RTY_i: std_logic;
  signal B_STALL_i: std_logic;
  signal B_DAT_i: std_logic_vector(c_dat_width_B-1 downto 0) ;

  signal inputs_vals : A_val := genA(num);
  signal output_vals : B_val;
  
  
  signal stim: natural;
  
  constant clock_period: time := 10 ns;
  signal stop_the_clock: boolean;

begin

  -- Insert values for generic parameters !!
  uut: WB_bus_adapter_streaming_sg generic map ( g_adr_width_A => c_adr_width_A ,
                                                 g_adr_width_B => c_adr_width_B ,
                                                 g_dat_width_A => c_dat_width_A ,
                                                 g_dat_width_B => c_dat_width_B ,
                                                 g_pipeline    =>  2)
                                      port map ( clk_i         => clk_i,
                                                 nRst_i        => nRst_i,
                                                 A_CYC_i       => A_CYC_i,
                                                 A_STB_i       => A_STB_i,
                                                 A_ADR_i       => A_ADR_i,
                                                 A_SEL_i       => A_SEL_i,
                                                 A_WE_i        => A_WE_i,
                                                 A_DAT_i       => A_DAT_i,
                                                 A_ACK_o       => A_ACK_o,
                                                 A_ERR_o       => A_ERR_o,
                                                 A_RTY_o       => A_RTY_o,
                                                 A_STALL_o     => A_STALL_o,
                                                 A_DAT_o       => A_DAT_o,
                                                 B_CYC_o       => B_CYC_o,
                                                 B_STB_o       => B_STB_o,
                                                 B_ADR_o       => B_ADR_o,
                                                 B_SEL_o       => B_SEL_o,
                                                 B_WE_o        => B_WE_o,
                                                 B_DAT_o       => B_DAT_o,
                                                 B_ACK_i       => B_ACK_i,
                                                 B_ERR_i       => B_ERR_i,
                                                 B_RTY_i       => B_RTY_i,
                                                 B_STALL_i     => B_STALL_i,
                                                 B_DAT_i       => B_DAT_i );
										 
  stimulus: process
  
    
  variable cnt : natural := num-1;
  

  
  
  begin
  

    -- Put initialisation code here
    wait until rising_edge(clk_i);
    A_CYC_i     <= '0';
	
	A_ADR_i     <= (others => '0');
	A_SEL_i     <= (others => '0');
	A_WE_i      <= '0';
	A_DAT_i		<= (others => '0');
    
	B_ERR_i     <= '0';
	B_RTY_i     <= '0';
	
	B_DAT_i		<= (others => '0');
	
	nRst_i <= '0';
    wait for clock_period;
    nRst_i <= '1';
    wait for clock_period*2;
    


A_STB_i <= '1';
	
	--begin testing
	while(cnt > 0) loop
	   
		if(A_STALL_o = '0') then
			A_DAT_i <= inputs_vals(cnt);
			cnt := cnt -1;
		end if;
		wait for clock_period;	
	end loop;	
	A_STB_i <= '0';
	
	
	wait for clock_period*30;
	
	
	
	
	
    
    -- Put test bench stimulus code here

    stop_the_clock <= true;
    wait;
  end process;

  clocking: process
  begin
    while not stop_the_clock loop
      clk_i <= '0', '1' after clock_period / 2;
      wait for clock_period;
    end loop;
    wait;
  end process;
  
  
   looping: process(clk_i)

    -- Seed values for random generator
variable seed1 : positive := 15412;
variable seed2 : positive := 37819;
-- Random real-number value in range 0 to 1.0
variable rand: real;
-- Random integer value in range 0..4095
variable int_rand: integer;
-- Random 12-bit stimulus

  variable i : natural := 0;
  
  begin
    if(rising_edge(clk_i)) then
      B_STALL_i <= '0';
      
      if(B_STALL_i = '0') then
        B_ACK_i <= B_STB_o;
      end if;   
    
	-- UNIFORM(seed1, seed2, rand);
	-- int_rand := INTEGER(TRUNC(rand*16.0));
   -- if(int_rand > 8) then
		-- B_STALL_i <= '0';
	-- else
		-- B_STALL_i <= '1';
	-- end if;
	
	if(B_STB_o = '1' AND B_STALL_i = '0') then
		output_vals(i) <= B_DAT_o;
		i := i+1;
	end if;		

		
	end if;	
  end process;

end;
  
