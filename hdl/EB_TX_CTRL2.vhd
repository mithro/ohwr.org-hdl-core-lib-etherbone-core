---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;
use work.wishbone_package.all;

entity EB_TX_CTRL is 
port(
		clk_i		: in std_logic;
		nRst_i		: in std_logic;
		
		--Eth MAC WB Streaming signals
		wb_slave_i	: in	wishbone_slave_in;
		wb_slave_o	: out	wishbone_slave_out;

		TX_master_slv_o          : out   std_logic_vector(70 downto 0);	--! Wishbone master output lines
		TX_master_slv_i          : in     std_logic_vector(35 downto 0)    --! 
		--TX_master_o     : out   wishbone_master_out;	--! Wishbone master output lines
		--TX_master_i     : in    wishbone_master_in    --!
		

		
		-- REP_MAC_i			: std_logic_vector(47 downto 0);
		-- REP_IP_i			: std_logic_vector(31 downto 0);
		-- REP_PORT_i			: std_logic_vector(15 downto 0);
		--EB Core Streaming signals
		-- udp_byte_len_i		: out unsigned(15 downto 0);
		
		-- valid_o				: std_logic
		
);
end entity;


architecture behavioral of EB_TX_CTRL is


type st is (IDLE, HDR_SEND, PAYLOAD_SEND, WAITSTATE);

signal state_tx 	: st := IDLE;

type stmux is (HEADER, PAYLOAD);

signal state_mux	: stmux := HEADER;


signal ETH_TX 		: ETH_HDR;
signal IPV4_TX 		: IPV4_HDR;
signal UDP_TX 		: UDP_HDR;

signal TX_HDR_slv 	: std_logic_vector(192 + 160 + 64-1 downto 0);
alias  ETH_TX_slv 	: std_logic_vector(192-1 downto 0) 	is TX_HDR_slv(192 + 160 + 64-1 downto 160 + 64);
alias  IPV4_TX_slv 	: std_logic_vector(160-1 downto 0) 	is TX_HDR_slv(160 + 64-1 downto 64);
alias  UDP_TX_slv 	: std_logic_vector(64-1 downto 0) 	is TX_HDR_slv(64-1 downto 0);

signal s_out 		: std_logic_vector(31 downto 0);
signal sh_TX_en 	: std_logic;
signal ld			: std_logic;

signal counter		: unsigned(31 downto 0);
signal stalled  	: std_logic;


signal  TX_master_o : wishbone_master_out;	--! Wishbone master output lines
signal  TX_master_i : wishbone_master_in;

signal  TX_hdr_o 				: wishbone_master_out;	--! Wishbone master output lines
signal  wb_payload_stall_o 	: wishbone_slave_out;


component piso_sreg_gen is 
generic(g_width_in : natural := 416; g_width_out : natural := 32);
 port(
		d_i		: in	std_logic_vector(g_width_in -1 downto 0);		--parallel in
		q_o		: out	std_logic_vector(g_width_out -1 downto 0);		--serial out
		clk_i	: in	std_logic;										--clock
		nRST_i	: in 	std_logic;
		en_i	: in 	std_logic;										--shift enable		
		ld_i	: in 	std_logic										--parallel load										
	);

end component;


begin

ETH_TX_slv	<= TO_STD_LOGIC_VECTOR(ETH_TX);
IPV4_TX_slv	<= TO_STD_LOGIC_VECTOR(IPV4_TX);
UDP_TX_slv	<= TO_STD_LOGIC_VECTOR(UDP_TX);

-- necessary to make QUARTUS SOPC builder see the WB intreface as conduit
TX_master_slv_o <=	TO_STD_LOGIC_VECTOR(TX_master_o);
TX_master_i		<=	TO_wishbone_master_in(TX_master_slv_i);

TX_hdr_o.DAT 	<=	s_out;

MUX_TX : with state_mux select 
TX_master_o	<=  TX_hdr_o 						when HEADER,
				wishbone_master_out(wb_slave_i)	when PAYLOAD,
				TX_hdr_o 						when others;

MUX_WB : with state_mux select
wb_slave_o <=	wb_payload_stall_o when HEADER,
				wishbone_slave_out(TX_master_i) when PAYLOAD,
				wishbone_slave_out(TX_master_i) when others;
				
shift_out : piso_sreg_gen
generic map (ETH_TX_slv'LENGTH + IPV4_TX_slv'LENGTH + UDP_TX_slv'LENGTH, 32) -- size is ETH + IPV4 + UDP
port map (

        clk_i  => clk_i,         --clock
        nRST_i => nRST_i,
        en_i   => sh_TX_en,      --shift enable        
        ld_i   => ld,            --parallel load
        d_i    => TX_HDR_slv,    --parallel in
        q_o    => s_out          --serial out
);

main_fsm : process(clk_i)
begin
	if rising_edge(clk_i) then

	   --==========================================================================
	   -- SYNC RESET                         
       --========================================================================== 
		if (nRST_i = '0') then
			ETH_TX 	<= INIT_ETH_HDR(c_MY_MAC);
			IPV4_TX <= INIT_IPV4_HDR(c_MY_IP);
			UDP_TX 	<= INIT_UDP_HDR(c_EB_PORT);
			
			IPV4_TX.TOL 	<= std_logic_vector(to_unsigned(112, 16));
			
			TX_hdr_o.CYC 	<= '0';
			TX_hdr_o.STB 	<= '0';
			TX_hdr_o.WE 	<= '1';
			TX_hdr_o.ADR 	<= (others => '0');
			TX_hdr_o.SEL  <= (others => '1');
			
			wb_payload_stall_o.STALL <= '1';
			wb_payload_stall_o.ACK 	<= '0';
			wb_payload_stall_o.DAT 	<= (others => '0');
			wb_payload_stall_o.ERR 	<= '0';
			wb_payload_stall_o.RTY 	<= '0';
			
			state_mux	<= HEADER;
			state_mux	<= HEADER;
			
			sh_TX_en 		<= '0';
			ld 				<= '0';
			stalled 	<= '0';
			counter 		<= (others => '0');
		else
			ETH_TX 	<= INIT_ETH_HDR (c_MY_MAC);
			IPV4_TX <= INIT_IPV4_HDR(c_MY_IP);
			UDP_TX 	<= INIT_UDP_HDR (c_EB_PORT);
			
			TX_hdr_o.STB 	<= '0';
			ld 				<= '0';
			
			case state_tx is
				when IDLE 			=> 	state_mux	<= HEADER;
										if(wb_slave_i.CYC = '1') then
											
											TX_hdr_o.CYC 		<= '1';
											TX_hdr_o.STB 		<= '1';
											sh_TX_en 			<= '1';
											ld 			<= '1';
											
											
										end if;
										
				
				when HDR_SEND		=> 	if(counter < 13) then
											if(TX_master_i.STALL = '0') then
												TX_hdr_o.STB <= '1';
												sh_TX_en <= '1';
												counter <= counter +1;	
											end if;											
										
											-- if(TX_master_i.STALL = '1') then
												-- stalled 	<= '1';
												
											-- else
												-- TX_hdr_o.STB <= '1';
												-- if(stalled  = '1') then
													-- stalled  <= '0';
												-- else
													-- sh_TX_en <= '1';
													-- counter_ouput <= counter_ouput +1;
												-- end if;
											-- end if;	
										else
											--TX_hdr_o.STB <= '1';
											state_mux    <= PAYLOAD;
											state_tx 		<= PAYLOAD_SEND;		
										end if;

				when PAYLOAD_SEND	=>  if(wb_slave_i.CYC = '0') then
											state_tx 		<= WAITSTATE;
											state_mux 		<= HEADER;
											state_mux	<= HEADER;	
											TX_hdr_o.CYC <= '0';
										end if;
				
				when WAITSTATE		=>	--ensure interframe gap
										if(counter < 100) then
											counter 		<= counter +1;
										else
											counter 		<= (others => '0');
											state_tx 		<= IDLE;
										end if;
	
				when others =>			state_tx <= IDLE;			
			
			
			end case;
			
					
			
			
		end if;
	end if;    
	
end process;



end behavioral;