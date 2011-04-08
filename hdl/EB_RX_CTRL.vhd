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
		slave_RX_stream_i	: in	wishbone_slave_in;
		slave_RX_stream_o	: out	wishbone_slave_out;

		master_RX_stream_i	: in	wishbone_master_in;
		master_RX_stream_o	: out	wishbone_master_out;

		
		REP_MAC_o			: std_logic_vector(47 downto 0);
		REP_IP_o			: std_logic_vector(31 downto 0);
		REP_PORT_o			: std_logic_vector(15 downto 0);
		--EB Core Streaming signals
		udp_byte_len_o		: out unsigned(15 downto 0);
		
		
		valid_o				: std_logic;
		
		

);
end entity;

architecture behavioral of is

constant c_width_int : integer := 24;

type state_rx is (IDLE, ADDUP, CARRIES, FINALISE, OUTPUT);

signal state 		: st := IDLE;

signal ETH_RX 	: ETH_HDR;
signal IPV4_RX 	: IPV4_HDR;
signal UDP_RX 	: UDP_HDR;

signal ETH_TX 	: ETH_HDR;
signal IPV4_TX 	: IPV4_HDR;
signal UDP_TX 	: UDP_HDR;

signal TX_HDR : std_logic_vector(ETH_TX'LENGTH + IPV4_TX'LENGTH + UDP_TX'LENGTH-1 downto 0);
alias  ETH_TX_slv 	: std_logic_vector(ETH_TX'LENGTH-1 downto 0) 	is TX_HDR(ETH_TX'LENGTH + IPV4_TX'LENGTH + UDP_TX'LENGTH-1 downto IPV4_TX'LENGTH + UDP_TX'LENGTH);
alias  IPV4_TX_slv 	: std_logic_vector(IPV4_TX'LENGTH-1 downto 0) 	is TX_HDR(IPV4_TX'LENGTH + UDP_TX'LENGTH-1 downto UDP_TX'LENGTH);
alias  UDP_TX_slv 	: std_logic_vector(UDP_TX'LENGTH-1 downto 0) 	is TX_HDR(UDP_TX'LENGTH-1 downto 0);

signal RX_HDR 		: std_logic_vector(ETH_RX'LENGTH + IPV4_RX'LENGTH + UDP_RX'LENGTH-1 downto 0);
alias  ETH_RX_slv 	: std_logic_vector(ETH_RX'LENGTH-1 downto 0) 	is RX_HDR(ETH_RX'LENGTH + IPV4_RX'LENGTH + UDP_RX'LENGTH-1 downto IPV4_RX'LENGTH + UDP_RX'LENGTH);
alias  IPV4_RX_slv 	: std_logic_vector(IPV4_RX'LENGTH-1 downto 0) 	is RX_HDR(IPV4_RX'LENGTH + UDP_RX'LENGTH-1 downto UDP_RX'LENGTH);
alias  UDP_RX_slv 	: std_logic_vector(UDP_RX'LENGTH-1 downto 0) 	is RX_HDR(UDP_RX'LENGTH-1 downto 0);

signal s_out 		: std_logic_vector(31 downto 0);
signal s_in 		: std_logic_vector(31 downto 0);

signal RX_sh_en 	: std_logic;
signal RX_ACK 		: std_logic;
signal RX_STALL		: std_logic;

signal TX_STB 		: std_logic;
signal TX_STALL		: std_logic;	
signal TX_sh_en 	: std_logic;

component sipo_sreg_gen is 
generic(g_width_in : natural := 32; g_width_out : natural := 416);
 port(
		d_i		: in	std_logic_vector(g_width_in -1 downto 0);		--serial in
		q_o		: out	std_logic_vector(g_width_out -1 downto 0);		--parallel out
		clk_i	: in	std_logic;										--clock
		nRST_i	: in 	std_logic;										--reset
		en_i	: in 	std_logic;										--shift enable		
		clr_i	: in 	std_logic										--clear
	);

end sipo_sreg_gen;

begin

udp_byte_len_o <= UDP_RX.LEN;

ETH_RX 	<= TO_ETH_HDR (ETH_RX_slv);
IPV4_RX <= TO_IPV4_HDR(IPV4_RX_slv);
UDP_RX 	<= TO_UDP_HDR (UDP_RX_slv);

ETH_TX_SLV	<= TO_STD_LOGIC_VECTOR(ETH_TX);
IPV4_TX_SLV	<= TO_STD_LOGIC_VECTOR(IPV4_TX);
UDP_TX_SLV	<= TO_STD_LOGIC_VECTOR(UDP_TX);

s_in 		<=	slave_RX_stream_i.DAT;

master_RX_stream_o.CYC <= RX_CYC;
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

shift_in : piso_sreg_gen
generic map (ETH_RX'LENGTH + IPV4_RX'LENGTH + UDP_RX'LENGTH) -- size is ETH + IPV4 + UDP
port map (

        clk_i  => clk_i,       --clock
        nRST_i => nRST_i,
        en_i   => sh_RX_en,    --shift enable        
        clr_i   => clr,        --clear
        d_i    => s_in,        --serial in
        q_o    => RX_HDR       --parallel out
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
		else
			ETH_TX 	: INIT_ETH_HDR (c_MY_MAC);
			IPV4_TX : INIT_IPV4_HDR(c_MY_IP);
			UDP_TX 	: INIT_UDP_HDR (c_EB_PORT);
			

			
			
			case state_rx is
				when IDLE 			=> 	eb_hdr_rec_count 		<= std_logic_vector(c_EB_HDR_LEN);
										eb_hdr_send_count 		<= std_logic_vector(c_EB_HDR_LEN);
										debugsum <= debugsum + debug_byte_diff;
										debug_byte_diff <= (others => '0');
										state_tx 				<= IDLE;
										state_rx 				<= EB_HDR_REC;
										--slave_RX_stream_o.STALL 	<=	'0';
										report "EB: RDY" severity note;
												

				when RX_HDR_START	=> 	if(slave_RX_stream_i.CYC = '1' AND slave_RX_stream_i.STB = '1' AND slave_RX_stream_i.WE = '1') then
											
											
											state_rx <= EB_HDR_PROC;
										end if;
				
				when RX_HDR_REC		=>	
				
				when RX_EB_REC		=> 	if() then
											report "EB: PACKET START" severity note;
											master_TX_stream_o.CYC <= '1';
											
										else
											
										end if;
				when others =>						

						
			if(slave_RX_stream_i.CYC = '1') then
				state_rxETH_HDR_REC
					
			
			
		end if;
	end if;    
	
end process;



end behavioral;