---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;

entity is EB_2_WB
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;
		
		--Eth MAC WB Streaming signals
		slave_RX_stream_i	: in	wishbone_slave_in;
		slave_RX_stream_o	: out	wishbone_slave_out
		
		master_TX_stream_i	: in	wishbone_master_in;
		master_TX_stream_o	: out	wishbone_master_out
		
		--WB IC signals
		master_IC_i	: in	wishbone_master_in;
		master_IC_o	: out	wishbone_master_out

);
end entity;

architecture behavioral of is

constant c_width_int : integer := 24;

type st is (IDLE, ADDUP, CARRIES, FINALISE, OUTPUT);

signal state 		: st := IDLE;

signal EB_RX : EB_HDR;
signal EB_TX : EB_HDR;

signal status_cnt : unsigned := 0;

signal RX_Stream_data_buff : std_logic_vector(31 downto 0);





begin

shift_in : piso_sreg_gen
generic map (EB_RX'LENGTH) -- size is IPV4+UDP+EB
port map (

        clk_i  => clk_i,                                        --clock
        nRST_i => nRST_i,
        en_i   => en,                        --shift enable        
        ld_i   => ld,                            --parallel load
        d_i    => p_in,        --parallel in
        q_o    => s_slv16_o                            --serial out
);




main: process(clk_i)
begin
	if rising_edge(clk_i) then

	   --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0') then
			EB_RX = INIT_EB_HDR;
			EB_TX = INIT_EB_HDR;
		else
			
			case state_main is
				when IDLE 		=> 	if(slave_RX_stream_i.CYC = '1' AND slave_RX_stream_i.STB = '1') then 
										state_RX 	= RECEIVING;
										EB_RX 		= INIT_EB_HDR;
										EB_TX 		= INIT_EB_HDR;
										MUX			= MUX_HDR;
									end if;	
				when RECEIVING  => 	if(slave_RX_stream_i.CYC = '0' OR rd_count_unf = '1') 					
									elsif(
									case state_RX is
										when IDLE 		=> 
										when RX_HDR		=> 	if(sipo_full = '1') then
																	
										when SETUP		=>
										when RX_DATA	=>
										when others 	=> state <= IDLE;
									end case;
				when SENDING	=>  case state_TX is
										when IDLE 		=> 
										when TX_HDR		=>
										when TX_DATA	=>
										when others 	=> state <= IDLE;
									end case;
				when others		=>	state_main <= IDLE;							
			if(state = IDLE)
				-- received Etherbone header. Process
				if(EB_RX.EB_MAGIC = EB_MAGIC_WORD) then	-- yup, seems to be Etherbone
					
					
			
			
		end if;
	end if;    
	
end process;

end behavioral;