---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;

entity EB_checksum is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;
		
		data_i	: in std_logic_vector(31 downto 0);
		ctrl_i	: in std_logic_vector(4 downto 0);
		
		done_o	: out std_logic;
		sum_o	: out std_logic_vector(15 downto 0)
);
end EB_checksum;

architecture behavioral of EB_checksum is

constant c_width_int : integer := 24;

type st is (IDLE, ADDUP, CARRIES, FINALISE, OUTPUT);

signal state 		: st := IDLE;
signal sum  		: unsigned(c_width_int-1 downto 0);
alias  sum_lo		: unsigned(15 downto 0) is sum(15 downto 0);

signal muxed_data 	: unsigned(31 downto 0);
signal data_reg		: unsigned(31 downto 0);
alias  data_reg_HI 	: unsigned(15 downto 0) is data_reg(31 downto 16);  	
alias  data_reg_LO 	: unsigned(15 downto 0) is data_reg(15 downto 0); 

alias clear		: std_logic is ctrl_i(0); 
alias add		: std_logic_vector(1 downto 0) is ctrl_i(2 downto 1);
alias en		: std_logic is ctrl_i(3);
alias done  : std_logic is ctrl_i(4); 
signal en_reg : std_logic;
signal done_reg : std_logic;

begin

with add select 
-- input word selector
muxed_data 	<= 	unsigned(data_i AND x"00FF") when "01", -- sum + LO word + 0
				unsigned(data_i AND x"FF00") when "10", -- sum + HI word + 0
				unsigned(data_i)			 when "11", -- sum + HI word + LO word
				(others => '0') when others;


adder: process(clk_i)
begin
	if rising_edge(clk_i) then
       	
		data_reg	<= muxed_data; 
		done_reg <= done;
		en_reg   <= en;
	   --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0' OR clear = '1') then
			done_o <= '0';
			sum 	  <= (others => '0');	
			state 	<= IDLE;	
		else
			--register input data
			sum_o <= NOT(std_logic_vector(sum_lo));
			
			case state is 
				when IDLE 		=> 	--clear internal states and output
															
									
									-- if enable flag is set, start checksum generation
									if(en = '1') then
										state <= ADDUP;
										done_o 	<= '0';
									end if;
				
				when ADDUP 	=> 	-- add the two 16 bit word if there was new data on the bus
									if(en_reg = '1') then
										sum <= sum + resize(unsigned(data_reg_HI), c_width_int) + resize(unsigned(data_reg_LO), c_width_int);
									end if;
									-- if thats all, take care of the carries
									if(done_reg = '1') then
										state <= CARRIES;
									else
										state <= ADDUP;
									end if;
				
				when CARRIES 	=>	sum <= resize((sum_LO), c_width_int) + resize(sum(c_width_int-1 downto 16), c_width_int);
									state <= FINALISE;
				
				when FINALISE 	=>	-- add carry bits from hi word to low word again, in case last sum produced overflow
									sum <= resize(sum_LO, c_width_int) + resize(sum(c_width_int-1 downto 16), c_width_int);
									state <= OUTPUT;
				
				when OUTPUT		=>  -- invert sum lo word, write to output. assert done flag
									done_o <= '1';
									state  <= IDLE;
				
				when others 	=> 	state <= IDLE;
			end case;
		end if;
	end if;    
	
end process;

end behavioral;