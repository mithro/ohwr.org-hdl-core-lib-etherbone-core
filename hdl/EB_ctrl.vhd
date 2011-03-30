---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;

entity is EB_CTRL
port(
		clk_i		: in std_logic;
		nRst_i		: in std_logic;
		
		--Eth MAC WB Streaming signals
		en_i		: std_logic;
		RX_data_i	: std_logic_vector(31 downto 0);
		
		en_o		: std_logic;
		TX_data_o	: std_logic_vector(31 downto 0); 	 
);
end entity;

architecture behavioral of is

constant c_width_int : integer := 24;

type st is (IDLE, ADDUP, CARRIES, FINALISE, OUTPUT);

signal state 		: st := IDLE;

signal ETH_RX 	: ETH_HDR;
signal IPV4_RX 	: IPV4_HDR;
signal UDP_RX 	: UDP_HDR;

signal ETH_TX 	: ETH_HDR;
signal IPV4_TX 	: IPV4_HDR;
signal UDP_TX 	: UDP_HDR;





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
			ETH_RX 	: TO_ETH_HDR ((others => '0'));
			IPV4_RX : TO_IPV4_HDR((others => '0'));
			UDP_RX 	: TO_UDP_HDR ((others => '0'));

			ETH_TX 	: INIT_ETH_HDR (c_MY_MAC);
			IPV4_TX : INIT_IPV4_HDR(c_MY_IP);
			UDP_TX 	: INIT_UDP_HDR (c_EB_PORT);
		else
			sample_RX <= '1';
			
				
			if(slave_RX_stream_i.DAT = EB_RX.EB_MAGIC) then	-- found Etherbone Header, start processing
					
			
			
		end if;
	end if;    
	
end process;

end behavioral;