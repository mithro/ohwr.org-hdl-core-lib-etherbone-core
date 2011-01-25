---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;

entity checksum_adder is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;
		clr_i	: in std_logic;
		en_i	: in std_logic; 
		data_i	: in std_logic_vector(15 downto 0);
		
		done_o	: out std_logic;
		sum_o	: out std_logic_vector(15 downto 0)
);
end checksum_adder;

architecture behavioral of checksum_adder is


type statetype is (IDLE, ADDUP, FINALISE, OUTPUT);

signal state 	: statetype := IDLE;
signal sum  	: unsigned(31 downto 0);
signal data 	: std_logic_vector(15 downto 0);


begin
gensum: process(clk_i)
begin
	if rising_edge(clk_i) then
       --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0' OR clr_i = '1') then
			done_o 	<= '0';
			sum_o 	 <= (others => '0');
			sum 	   <= (others => '0');	
			state   <= IDLE;	
			
		else
			--register input data
			data <= data_i;
			
			case state is 
				when IDLE 		   => 	--clear internal states and output
									done_o 	<= '0';
									sum_o 	 <= (others => '0');
									sum 	   <= (others => '0');									
									
									-- if enable flag is set, start checksum generation
									if(en_i = '1') then
										state <= ADDUP;
									end if;
				
				when ADDUP 	  	=> 	
									if(en_i = '1') then
										-- add up all incoming 16 bit words
										sum   <= sum + resize(unsigned(data), 32);
									else
										-- end of data block. add carry bits from hi word to low word
										sum   <= resize(sum(15 downto 0), 32) + resize(sum(31 downto 16), 32);
										state <= FINALISE;
									end if;
				
				when FINALISE 	=>	-- add carry bits from hi word to low word again, in case last sum produced overflow
									sum   <= resize(sum(15 downto 0), 32) + resize(sum(31 downto 16), 32);
									state <= OUTPUT;
				
				when OUTPUT		  =>  -- invert sum lo word, write to output. assert done flag
									sum_o  <= NOT(std_logic_vector(sum(15 downto 0)));
									done_o <= '1';
									state  <= IDLE;
				
				when others 	  => 	state <= IDLE;
			end case;
		end if;
	end if;    
	
end process;

end behavioral;