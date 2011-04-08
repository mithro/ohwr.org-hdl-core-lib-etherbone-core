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
		slave_TX_stream_i	: in	wishbone_slave_in;
		slave_TX_stream_o	: out	wishbone_slave_out;

		master_TX_stream_i	: in	wishbone_master_in;
		master_TX_stream_o	: out	wishbone_master_out;

		
		-- REP_MAC_i			: std_logic_vector(47 downto 0);
		-- REP_IP_i			: std_logic_vector(31 downto 0);
		-- REP_PORT_i			: std_logic_vector(15 downto 0);
		--EB Core Streaming signals
		-- udp_byte_len_i		: out unsigned(15 downto 0);
		
		-- valid_o				: std_logic
		
);
end entity;

architecture behavioral of is

constant c_width_int : integer := 24;

type state_rx is (IDLE, ADDUP, CARRIES, FINALISE, OUTPUT);

signal state 		: st := IDLE;

signal ETH_TX 	: ETH_HDR;
signal IPV4_TX 	: IPV4_HDR;
signal UDP_TX 	: UDP_HDR;

signal TX_HDR_slv : std_logic_vector(ETH_TX'LENGTH + IPV4_TX'LENGTH + UDP_TX'LENGTH-1 downto 0);
alias  ETH_TX_slv 	: std_logic_vector(ETH_TX'LENGTH-1 downto 0) 	is TX_HDR(ETH_TX'LENGTH + IPV4_TX'LENGTH + UDP_TX'LENGTH-1 downto IPV4_TX'LENGTH + UDP_TX'LENGTH);
alias  IPV4_TX_slv 	: std_logic_vector(IPV4_TX'LENGTH-1 downto 0) 	is TX_HDR(IPV4_TX'LENGTH + UDP_TX'LENGTH-1 downto UDP_TX'LENGTH);
alias  UDP_TX_slv 	: std_logic_vector(UDP_TX'LENGTH-1 downto 0) 	is TX_HDR(UDP_TX'LENGTH-1 downto 0);

signal s_out 		: std_logic_vector(31 downto 0);

signal TX_sh_en 	: std_logic;


begin

udp_byte_len_o <= UDP_RX.LEN;

ETH_RX 	<= TO_ETH_HDR (ETH_RX_slv);
IPV4_RX <= TO_IPV4_HDR(IPV4_RX_slv);
UDP_RX 	<= TO_UDP_HDR (UDP_RX_slv);

ETH_TX_SLV	<= TO_STD_LOGIC_VECTOR(ETH_TX);
IPV4_TX_SLV	<= TO_STD_LOGIC_VECTOR(IPV4_TX);
UDP_TX_SLV	<= TO_STD_LOGIC_VECTOR(UDP_TX);

s_out 		<=	slave_TX_stream_o.DAT;

master_TX_stream_o.CYC <= TX_CYC;

shift_out : piso_sreg_gen
generic map (ETH_TX'LENGTH + IPV4_TX'LENGTH + UDP_TX'LENGTH) -- size is ETH + IPV4 + UDP
port map (

        clk_i  => clk_i,         --clock
        nRST_i => nRST_i,
        en_i   => sh_TX_en,      --shift enable        
        ld_i   => ld,            --parallel load
        d_i    => TX_HDR,        --parallel in
        q_o    => s_out          --serial out
);


main_fsm : process(clk_i)
begin
	if rising_edge(clk_i) then

	   --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0') then
			ETH_TX 	: INIT_ETH_HDR (c_MY_MAC);
			IPV4_TX : INIT_IPV4_HDR(c_MY_IP);
			UDP_TX 	: INIT_UDP_HDR (c_EB_PORT);
			
			IPV4_TX.TOL <= to_unsigned(112, 16);
			
			
			wb_master_o.CYC <= '0';
			wb_master_o.STB <= '0';
			wb_master_o.WE 	<= '1';
			wb_master_o.DAT <= (others => '0');
			TX_sh_en <= '0';
			ld 		<= '0';
		else
			ETH_TX 	: INIT_ETH_HDR (c_MY_MAC);
			IPV4_TX : INIT_IPV4_HDR(c_MY_IP);
			UDP_TX 	: INIT_UDP_HDR (c_EB_PORT);
			
			wb_master_o.STB 	<= '0';
			ld 					<= '0';
			
			case state_tx is
				when IDLE 			=> 	wb_master_o.CYC 		<= '1';
										state_tx 				<= TX_HDR_SEND;
										ld 						<= '1';
												

				when HDR_SEND	=> 	if(counter < 13) then
										
											if(wb_master_i.STALL = '1') then
												stalled 			<= '1';
												TX_sh_en 			<= '0';
											else
												if(stalled  = '1') then
													stalled  		<= '0';
													wb_master_o.STB <= '1';
												else
													TX_sh_en 		<= '1';
													counter <= counter +1;
												end if;
											end if;	
										else
											
											state_tx <= WAITSTATE;		
										end if;

				when PAYLOAD_SEND	=>  --MUX to EB
										if(counter < 30) then
											counter <= counter +1;
										else
											wb_master_o.CYC 		<= '0';
										end if;
				
				
				when WAITSTATE		=>	if(counter < 140) then
											counter <= counter +1;
										else
											counter <= (others => '0');
											state_tx <= IDLE;
										end if;
	
				
				
				
				when others =>			state_tx <= IDLE;			
			
			
			end case;
			
					
			
			
		end if;
	end if;    
	
end process;



end behavioral;