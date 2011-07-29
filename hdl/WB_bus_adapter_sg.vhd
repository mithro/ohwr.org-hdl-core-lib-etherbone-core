---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.vhdl_2008_workaround_pkg.all;

entity WB_bus_adapter is
generic(g_adr_width_A : natural := 16; g_adr_width_B  : natural := 32;
		g_dat_width_A : natural := 64; g_dat_width_B  : natural := 16;
		g_pipeline    : natural := 0);
		--0 pipeline 		A => not pipeline 	B
		--1 not pipeline 	A => pipeline 		B
		--2 pipeline 		A => not pipeline 	B
		--3 pipeline 		A => pipeline 		B
port(
		clk_i		: in std_logic;
		nRst_i		: in std_logic;
		
		A_CYC_i		: std_logic;
		A_STB_i		: std_logic;
		A_ADR_i		: std_logic_vector(g_adr_width_A-1 downto 0);
		A_SEL_i		: std_logic_vector(g_dat_width_A/8-1 downto 0);
		A_WE_i		: std_logic;
		A_DAT_i		: std_logic_vector(g_dat_width_A-1 downto 0);
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
		B_ACK_i		: std_logic;
		B_ERR_i		: std_logic;
		B_RTY_i		: std_logic;
		B_STALL_i	: std_logic;
		B_DAT_i		: std_logic_vector(g_dat_width_B-1 downto 0)

);
end WB_bus_adapter_direct;




architecture behavioral of WB_bus_adapter is

	constant c_adr_w_max : natural := maximum(g_adr_width_A, g_adr_width_B);
	constant c_dat_w_max : natural := maximum(g_dat_width_A, g_dat_width_B);
	constant c_sel_w_max : natural := maximum(g_dat_width_A, g_dat_width_B)/8;
	constant c_adr_w_min : natural := minimum(g_adr_width_A, g_adr_width_B);
	constant c_dat_w_min : natural := minimum(g_dat_width_A, g_dat_width_B);
	constant c_sel_w_min : natural := minimum(g_dat_width_A, g_dat_width_B)/8;
	
	-- direct adapter signals
	constant c_adr_pad 	: std_logic_vector(c_adr_w_max-1 downto 0) 	:=  (others => '0');
	constant c_sel_pad 	: std_logic_vector(c_sel_w_max-1 downto 0) 	:=  (others => '0');
	constant c_dat_pad 	: std_logic_vector(c_dat_w_max-1 downto 0) 	:=  (others => '0');
	
	signal 	adr 		: std_logic_vector(c_adr_w_max-1 downto 0);
	signal 	slave_dat 	: std_logic_vector(c_dat_w_max-1 downto 0);
	signal 	master_dat 	: std_logic_vector(c_dat_w_max-1 downto 0);
	signal 	sel 		: std_logic_vector(c_sel_w_max-1 downto 0);
	
	-- S/G adapter signals
	signal sipo_sh_in 	: std_logic;
	signal sipo_clr 	: std_logic;
	signal sipo_full 	: std_logic;
	
	signal piso_sh_out 	: std_logic;
	signal piso_ld_in 	: std_logic;
	signal piso_empty 	: std_logic;
	
	
	component sipo_full_flag is
	generic(g_width_IN : natural := 16; g_width_OUT  : natural := 32); 
	port(
			clk_i				: in std_logic;
			nRst_i				: in std_logic;
			
			d_i					: in std_logic_vector(g_width_IN-1 downto 0);
			en_i				: in std_logic;
			clr_i				: in std_logic;
			
			q_o					: out std_logic_vector(g_width_OUT-1 downto 0);
			full_o				: out std_logic

	);
	end component;
	
	component piso_empty_flag is
	generic(g_width_IN : natural := 16; g_width_OUT  : natural := 32); 
	port(
			clk_i				: in std_logic;
			nRst_i				: in std_logic;
			
			d_i					: in std_logic_vector(g_width_IN-1 downto 0);
			en_i				: in std_logic;
			ld_i				: in std_logic;
			
			q_o					: out std_logic_vector(g_width_OUT-1 downto 0);
			empty_o				: out std_logic

	);
	end component;

begin

----------------------------------------------------------------------------------------------------------------------
------------------	Direct Bus Adapter	- No S/G	------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
DIRECT : if(g_scatter_gather = 0) GENERATE

	-- B side Outputs
	B_CYC_o		<= A_CYC_i;
	B_STB_o		<= A_STB_i;
	B_WE_o		<= A_WE_i;

	adr 		<= c_adr_pad(adr'length-1 downto  A_ADR_i'length) & A_ADR_i;
	B_ADR_o 	<= adr(g_adr_width_B-1 	downto 0);

	sel 		<= c_sel_pad(sel'length-1 downto  A_SEL_i'length) & A_SEL_i;
	B_SEL_o 	<= sel(g_dat_width_B/8-1 downto 0);

	master_dat 	<= c_dat_pad(master_dat'length-1 downto  A_DAT_i'length) & A_DAT_i;
	B_DAT_o 	<= master_dat(g_dat_width_B-1 downto 0);
	

	-- A side Outputs	
	G_CHECK_SEL : if(c_dat_w_max = g_dat_width_A) GENERATE
		A_ERR_o		<= B_ERR_i when (unsigned(A_SEL_i(g_dat_width_A/8-1 downto g_dat_width_B/8)) /= 0)
				else	'1';
	end GENERATE;

	G_NO_CHECK_SEL : if(c_dat_w_max = g_dat_width_B) GENERATE
		A_ERR_o		<= B_ERR_i;
	end GENERATE;

	A_ACK_o		<= B_ACK_i;
	A_RTY_o		<= B_RTY_i;
	A_STALL_o	<= B_STALL_i;

	slave_dat 	<= c_dat_pad(slave_dat'length-1 downto  B_DAT_i'length) & B_DAT_i;
	A_DAT_o 	<= slave_dat(g_dat_width_A-1 downto 0);

end GENERATE;
----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
------------------	Scatter/Gather Bus Adapter	----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
SG : if(g_scatter_gather = 1) GENERATE
	
	
	
---------------------------------------------------------------------------------------------------------------------------------	
	A_GE_B	:	if(c_dat_w_max = g_dat_width_A) GENERATE
		
		-- 	A -> B scatter
		-- master PI, slave SO
		scatter : piso_empty_flag is
		generic map(g_width_IN <= g_dat_width_A, g_width_OUT  <= g_dat_width_B) 
		port map(
			clk_i		<= clk_i,
			nRst_i		<= nRSt_i,
			
			d_i			<= B_DAT_i,
			en_i		<= piso_sh_out,
			ld_i		<= piso_ld_in,
			
			q_o			<= A_DAT_o,
			empty_o		<= piso_empty
		);
		
		B_STB_o			<= NOT piso_empty;
		
		if(
		piso_sh_out 	<= AND
			
			
		-- 	A <- B gather
		-- slave SI, master PO
		gather : sipo_full_flag is
		generic map(g_width_IN <= g_dat_width_B, g_width_OUT  <= g_dat_width_A) 
		port map(
			clk_i		<= clk_i,
			nRst_i		<= nRSt_i,
			
			d_i			<= B_DAT_i,
			en_i		<= sipo_sh_in,
			clr_i		<= sipo_clr,
			
			q_o			<= A_DAT_o,
			full_o		<= sipo_full
		);
		
		A_ACK_o			<= sipo_full;
		sipo_sh_in		<= B_ACK_i;
		
		-- Your VHDL code defining the model goes here
		process (clk_i)
		begin
			if (clk_i'event and clk_i = '1') then
				if(nRSt_i = '0') then

				else
					sipo_clr 	<= '0';
					piso_ld 	<= '0';
					
					
					if(en_i = '1' AND full = '0') then
						sh_reg <= sh_reg(g_width_OUT - g_width_IN downto 0) & d_i;
					end if;	
				end if;	
			end if;
		end process;
		
	end GENERATE;

---------------------------------------------------------------------------------------------------------------------------------
	A_LE_B	:	if(c_dat_w_max = g_dat_width_B) GENERATE
	
		-- 	A -> B gather
		-- master SI, slave PO
		gather : sipo_full_flag is
		generic map(g_width_IN <= g_dat_width_A, g_width_OUT  <= g_dat_width_B) 
		port map(
			clk_i		<= clk_i,
			nRst_i		<= nRSt_i,
			
			d_i			<= A_DAT_i,
			en_i		<= sipo_sh_in,
			clr_i		<= sipo_clr,
			
			q_o			<= B_DAT_o,
			full_o		<= sipo_full
		);
		
		B_STB_o 	<= sipo_full;
		sipo_sh_in 	<= A_STB_i AND NOT B_STALL_i;
		
		-- 	A <- B scatter
		-- slave PI, master SO
		scatter : piso_empty_flag is
		generic map(g_width_IN <= g_dat_width_B, g_width_OUT  <= g_dat_width_A) 
		port map(
			clk_i		<= clk_i,
			nRst_i		<= nRSt_i,
			
			d_i			<= B_DAT_i,
			en_i		<= piso_sh_out,
			ld_i		<= piso_ld_in,
			
			q_o			<= A_DAT_o,
			empty_o		<= piso_empty
		);
	
	end GENERATE;
	
	--  Your VHDL code defining the model goes here
	process (clk_i)
	begin
		if (clk_i'event and clk_i = '1') then
			if(nRSt_i = '0' OR clr_i = '1') then
				sh_reg 		<= (others => '0');
				sh_reg(0) 	<= '1';
			else
				if(en_i = '1' AND full = '0') then
					sh_reg <= sh_reg(g_width_OUT - g_width_IN downto 0) & d_i;
				end if;	
			end if;	
		end if;
	end process;
	
	
end GENERATE;

end architecture;