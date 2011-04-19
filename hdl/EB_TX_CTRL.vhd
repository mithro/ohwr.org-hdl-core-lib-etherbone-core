---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;
use work.EB_components_pkg.all;
use work.wishbone_package.all;

entity EB_TX_CTRL is 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		--Eth MAC WB Streaming signals
		wb_slave_i			: in	wishbone_slave_in;
		wb_slave_o			: out	wishbone_slave_out;

		--TX_master_slv_o     : out   std_logic_vector(70 downto 0);	--! Wishbone master output lines
		--TX_master_slv_i     : in     std_logic_vector(35 downto 0);    --! 
		TX_master_o     : out   wishbone_master_out;	--! Wishbone master output lines
		TX_master_i     : in    wishbone_master_in;    --!
		

		
		reply_MAC_i			: in  std_logic_vector(47 downto 0);
		reply_IP_i			: in  std_logic_vector(31 downto 0);
		reply_PORT_i		: in  std_logic_vector(15 downto 0);

		TOL_i				: in std_logic_vector(15 downto 0);
		
		valid_i				: in std_logic
		
);
end entity;


architecture behavioral of EB_TX_CTRL is


type st is (IDLE, CALC_CHKSUM, WAIT_SEND_REQ, HDR_SEND, PAYLOAD_SEND, WAIT_IFGAP);

signal state_tx 	: st := IDLE;

type stmux is (HEADER, PAYLOAD);

signal state_mux	: stmux := HEADER;


signal ETH_TX 		: ETH_HDR;
signal IPV4_TX 		: IPV4_HDR;
signal UDP_TX 		: UDP_HDR;

signal TX_HDR_slv 	: std_logic_vector(128 + 160 + 64-1 downto 0);
alias  ETH_TX_slv 	: std_logic_vector(128-1 downto 0) 	is TX_HDR_slv(128 + 160 + 64-1 downto 160 + 64);
alias  IPV4_TX_slv 	: std_logic_vector(160-1 downto 0) 	is TX_HDR_slv(160 + 64-1 downto 64);
alias  UDP_TX_slv 	: std_logic_vector(64-1 downto 0) 	is TX_HDR_slv(64-1 downto 0);

signal s_out 		: std_logic_vector(31 downto 0);
signal sh_TX_en 	: std_logic;
signal ld_tx_hdr	: std_logic;

signal counter_ouput		: unsigned(7 downto 0);
signal counter_chksum		: unsigned(7 downto 0);

signal stalled  	: std_logic;


--signal  TX_master_o : wishbone_master_out;	--! Wishbone master output lines
--signal  TX_master_i : wishbone_master_in;

signal  TX_hdr_o 				: wishbone_master_out;	--! Wishbone master output lines
signal  wb_payload_stall_o 	: wishbone_slave_out;

signal 	p_chk_vals		: std_logic_vector(95 downto 0);
signal  s_chk_vals		: std_logic_vector(15 downto 0);
	
signal 	IP_chk_sum		: std_logic_vector(15 downto 0);

signal  sh_chk_en 		: std_logic;         
signal  calc_chk_en	: std_logic;
signal  ld_p_chk_vals		: std_logic;            --parallel load







  signal chksum_done : std_logic;




begin

ETH_TX_slv	<= TO_STD_LOGIC_VECTOR(ETH_TX);
IPV4_TX_slv	<= TO_STD_LOGIC_VECTOR(IPV4_TX);
UDP_TX_slv	<= TO_STD_LOGIC_VECTOR(UDP_TX);

-- necessary to make QUARTUS SOPC build_tx_hdrer see the WB intreface as conduit
--TX_master_slv_o <=	TO_STD_LOGIC_VECTOR(TX_master_o);
--TX_master_i		<=	TO_wishbone_master_in(TX_master_slv_i);

TX_hdr_o.DAT 	<=	s_out;

MUX_TX : with state_mux select 
TX_master_o	<=  TX_hdr_o 						when HEADER,
				wishbone_master_out(wb_slave_i)	when PAYLOAD,
				TX_hdr_o 						when others;

MUX_WB : with state_mux select
wb_slave_o <=	wb_payload_stall_o when HEADER,
				wishbone_slave_out(TX_master_i) when PAYLOAD,
				wishbone_slave_out(TX_master_i) when others;

			
				
shift_hdr_chk_sum : piso_sreg_gen
generic map (96, 16) -- size is ETH + IPV4 + UDP
port map (

        clk_i  => clk_i,         --clock
        nRST_i => nRST_i,
        en_i   => sh_chk_en,      --shift enable        
        ld_i   => ld_p_chk_vals,            --parallel load
        d_i    => p_chk_vals,    --parallel in
        q_o    => s_chk_vals          --serial out
);

p_chk_vals		<= x"C511" & IPV4_TX.SRC & IPV4_TX.DST & IPV4_TX.TOL;

chksum_generator: EB_checksum port map ( clk_i  => clk_i,
                              nRst_i => nRst_i,
                              en_i   => calc_chk_en,
                              data_i => s_chk_vals,
                              done_o => chksum_done,
                              sum_o  => IP_chk_sum );

				
shift_out : piso_sreg_gen
generic map (ETH_TX_slv'LENGTH + IPV4_TX_slv'LENGTH + UDP_TX_slv'LENGTH, 32) -- size is ETH + IPV4 + UDP
port map (

        clk_i  => clk_i,         --clock
        nRST_i => nRST_i,
        en_i   => sh_TX_en,      --shift enable        
        ld_i   => ld_tx_hdr,            --parallel load
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
			ETH_TX 					<= INIT_ETH_HDR(c_MY_MAC);
			IPV4_TX 				<= INIT_IPV4_HDR(c_MY_IP);
			UDP_TX 					<= INIT_UDP_HDR(c_EB_PORT);
			
			IPV4_TX.TOL 			<= std_logic_vector(to_unsigned(112, 16));
			
			TX_hdr_o.CYC 			<= '0';
			TX_hdr_o.STB 			<= '0';
			TX_hdr_o.WE 			<= '1';
			TX_hdr_o.ADR 			<= (others => '0');
			TX_hdr_o.SEL  			<= (others => '1');
			
			wb_payload_stall_o.STALL <= '1';
			wb_payload_stall_o.ACK 	<= '0';
			wb_payload_stall_o.DAT 	<= (others => '0');
			wb_payload_stall_o.ERR 	<= '0';
			wb_payload_stall_o.RTY 	<= '0';
			
			state_mux				<= HEADER;
			
			sh_TX_en 				<= '0';
			ld_tx_hdr 				<= '0';
			stalled 				<= '0';
			counter_ouput 			<= (others => '0');
			counter_chksum			<= (others => '0');
			 -- prepare chk sum field_tx_hdr, fill in reply IP and TOL field_tx_hdr when available
			ld_p_chk_vals			<= '0';
			sh_chk_en				<= '0';
			calc_chk_en 			<= '0';
		else
			
			TX_hdr_o.STB 			<= '0';
			
			ld_tx_hdr 				<= '0';
			sh_TX_en 	  			<= '0';
			
			ld_p_chk_vals			<= '0';
			sh_chk_en				<= '0';
			calc_chk_en				<= '0';
			
			case state_tx is
				when IDLE 			=>  ETH_TX 				<= INIT_ETH_HDR (c_MY_MAC);
										IPV4_TX 			<= INIT_IPV4_HDR(c_MY_IP);
										UDP_TX 				<= INIT_UDP_HDR (c_EB_PORT);
										state_mux			<= HEADER;
										counter_chksum 		<= (others => '0');
										counter_ouput 		<= (others => '0');
										
										if(valid_i = '1') then
											ETH_TX.DST  	<= reply_MAC_i;
											IPV4_TX.DST		<= reply_IP_i;
											IPV4_TX.TOL		<= TOL_i;
											UDP_TX.MLEN		<= std_logic_vector(unsigned(TOL_i)-20);	
											UDP_TX.DST_PORT	<= reply_PORT_i;
											ld_p_chk_vals	<= '1';
											state_tx 		<= CALC_CHKSUM;		
										end if;
				
				when CALC_CHKSUM	=>	if(counter_chksum < 6) then
											sh_chk_en <= '1';
											calc_chk_en 	<= '1';
											counter_chksum 	<= counter_chksum +1;
										else
											if(chksum_done = '1') then
												IPV4_TX.SUM	<= IP_chk_sum;
												ld_tx_hdr 	<= '1';
												state_tx 	<= WAIT_SEND_REQ;
											end if;
										end if;	
				
				when WAIT_SEND_REQ	=>	state_mux	<= HEADER;	
										if(wb_slave_i.CYC = '1') then
											TX_hdr_o.CYC 	<= '1';
											TX_hdr_o.STB 	<= '1';
											sh_TX_en 		<= '1';
											state_tx 		<= HDR_SEND;
										end if;
										
				
				when HDR_SEND		=> 	if(counter_ouput < 10) then
											if(TX_master_i.STALL = '0') then
												TX_hdr_o.STB <= '1';
												sh_TX_en 	<= '1';
												counter_ouput <= counter_ouput +1;	
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
											state_mux    	<= PAYLOAD;
											state_tx 		<= PAYLOAD_SEND;		
										end if;

				when PAYLOAD_SEND	=>  if(wb_slave_i.CYC = '0') then
											state_tx 		<= WAIT_IFGAP;
											state_mux 		<= HEADER;	
											TX_hdr_o.CYC <= '0';
										end if;
				
				when WAIT_IFGAP		=>	--ensure interframe gap
										if(counter_ouput < 100) then
											counter_ouput 	<= counter_ouput +1;
										else
											state_tx 		<= IDLE;
										end if;
	
				when others =>			state_tx <= IDLE;			
			
			
			end case;
			
					
			
			
		end if;
	end if;    
	
end process;



end behavioral;