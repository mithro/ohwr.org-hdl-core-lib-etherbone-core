-------------------------------------------------------------------------------
-- White Rabbit Switch / GSI BEL
-------------------------------------------------------------------------------
--
-- unit name: Parallel-In/Serial-Out shift register
--
-- author: Mathias Kreider, m.kreider@gsi.de
--
-- date: $Date:: $:
--
-- version: $Rev:: $:
--
-- description: <file content, behaviour, purpose, special usage notes...>
-- <further description>
--
-- dependencies: <entity name>, ...
--
-- references: <reference one>
-- <reference two> ...
--
-- modified by: $Author:: $:
--
-------------------------------------------------------------------------------
-- last changes: <date> <initials> <log>
-- <extended description>
-------------------------------------------------------------------------------
-- TODO: <next thing to do>
-- <another thing to do>
--
-- This code is subject to GPL
-------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity led_ctrl_pwm is 
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		led_cfg_i		: in std_logic_vector(31 downto 0); 

		led_o			: out	std_logic
		
);

end led_ctrl_pwm;


architecture behavioral of led_ctrl_pwm is

type LED is record
	src_sel			: 	std_logic_vector(1 downto 0);   
	src_pol			:	std_logic;
	stat_val		: 	std_logic;   	
	reserved		: 	std_logic_vector(3 downto 0);    
	
	pwm_pol			:	std_logic; 
	pwm_duty		: 	std_logic_vector(6 downto 0);
	
	pwm_t			: 	std_logic_vector(15 downto 0);
end record;

function TO_LED(X : std_logic_vector)
return LED is
    variable tmp : LED;
    begin
        tmp.src_sel   	:= X(1 downto 0);
        tmp.src_pol   	:= X(2);
        tmp.stat_val  	:= X(3);
        tmp.pwm_pol			:= X(8);
		tmp.pwm_duty		:= X(15 downto 9);
		tmp.pwm_t        	:= X(31 downto 16);
    return tmp;
end function TO_LED;

signal MYLED : LED;

signal s_pwm_cnt 	: natural;
signal s_clk_div	: unsigned(16 downto 0);
signal s_clk_div_reg: std_logic;
signal s_clk_div_ovf: std_logic;

signal s_pwm_clk 	: std_logic;
signal s_t		 	: natural;
signal s_duty	 	: natural;
signal s_t_duty  	: natural;

signal s_pwm_val  	: std_logic;
signal s_pwm_val_pol	: std_logic;
signal s_led_val  	: std_logic;

begin

MYLED <= TO_LED(led_cfg_i);

s_pwm_val_pol <= s_pwm_val when MYLED.pwm_pol = '0'
			else NOT s_pwm_val;

with MYLED.src_sel select
s_led_val <= 	'0' when "00",
				MYLED.stat_val when "01",
				s_pwm_val_pol when "10",
				'0' when others;
			
	
led_o <= 	s_led_val when MYLED.src_pol = '0'
			else  NOT s_led_val;

s_t		<= to_integer(unsigned(MYLED.pwm_t));



clk_div	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then
			s_clk_div <= (others => '0');
		else
			s_clk_div_reg 	<= s_clk_div(s_clk_div'left);
			s_clk_div 		<= s_clk_div + 1;
			s_clk_div_ovf 	<= s_clk_div(s_clk_div'left) AND NOT s_clk_div_reg;
		end if;
    end if;
end process;

pwm	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then
			s_pwm_cnt <= 0;
			s_pwm_val <= '1';
		else
			if(s_clk_div_ovf = '1') then 
				s_pwm_cnt <= s_pwm_cnt + 1;
				if(s_pwm_cnt >= s_t) then
					s_pwm_cnt <= 0;
					s_pwm_val <= '1';
				end if;
				if(s_pwm_cnt = s_t_duty) then
					s_pwm_val <= '0';	
				end if;
			end if;	
		end if;
    end if;
end process;
	
calc_duty	:	process (clk_i)
  begin
    
	if (clk_i'event and clk_i = '1') then
		 if(nRSt_i = '0') then
			s_t_duty <= 1;
		else
			s_t_duty <= to_integer(unsigned(MYLED.pwm_duty)) * to_integer(unsigned(MYLED.pwm_t(MYLED.pwm_t'left downto 7)));
		end if;
	end if;
end process;
  
end behavioral;