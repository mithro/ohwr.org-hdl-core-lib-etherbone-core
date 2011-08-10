---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
use work.EB_HDR_PKG.all;
use work.wb32_package.all;
use work.wb16_package.all;

entity EB_TX_CTRL is 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		--Eth MAC WB Streaming signals
		wb_slave_i			: in	wb32_slave_in;
		wb_slave_o			: out	wb32_slave_out;

		TX_master_o     	: out   wb16_master_out;	--! Wishbone master output lines
		TX_master_i     	: in    wb16_master_in;    --!
		

		
		reply_MAC_i			: in  std_logic_vector(47 downto 0);
		reply_IP_i			: in  std_logic_vector(31 downto 0);
		reply_PORT_i		: in  std_logic_vector(15 downto 0);

		TOL_i				: in std_logic_vector(15 downto 0);
		
		valid_i				: in std_logic
		
);
end entity;


architecture behavioral of EB_TX_CTRL is

component EB_checksum is
port(
		clk_i	: in std_logic;
		nRst_i	: in std_logic;
		
		en_i	: in std_logic; 
		data_i	: in std_logic_vector(15 downto 0);
		
		done_o	: out std_logic;
		sum_o	: out std_logic_vector(15 downto 0)
);
end component;

component WB_bus_adapter_streaming_sg
  generic(g_adr_width_A : natural := 32; g_adr_width_B  : natural := 32;
  		g_dat_width_A : natural := 32; g_dat_width_B  : natural := 16;
  		g_pipeline : natural 
  		);
  port(
  		clk_i		: in std_logic;
  		nRst_i		: in std_logic;
  		A_CYC_i		: in std_logic;
  		A_STB_i		: in std_logic;
  		A_ADR_i		: in std_logic_vector(g_adr_width_A-1 downto 0);
  		A_SEL_i		: in std_logic_vector(g_dat_width_A/8-1 downto 0);
  		A_WE_i		: in std_logic;
  		A_DAT_i		: in std_logic_vector(g_dat_width_A-1 downto 0);
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
  		B_ACK_i		: in std_logic;
  		B_ERR_i		: in std_logic;
  		B_RTY_i		: in std_logic;
  		B_STALL_i	: in std_logic;
  		B_DAT_i		: in std_logic_vector(g_dat_width_B-1 downto 0)
  );
  end component;

component piso_flag is
generic(g_width_IN : natural := 16; g_width_OUT  : natural := 32); 
port(
		clk_i				: in std_logic;
		nRst_i				: in std_logic;
		
		d_i					: in std_logic_vector(g_width_IN-1 downto 0);
		en_i				: in std_logic;
		ld_i				: in std_logic;
		
		q_o					: out std_logic_vector(g_width_OUT-1 downto 0);
		full_o				: out std_logic;
		empty_o				: out std_logic
);
  end component;
  
signal conv_B    : wb16_master_out;	--! Wishbone master output lines
signal conv_A    : wb32_slave_out;    --!

-- main FSM
type st is (IDLE, CALC_CHKSUM, WAIT_SEND_REQ, HDR_SEND, PAYLOAD_SEND, WAIT_IFGAP);
signal state_tx 		: st := IDLE;

-- convert shift register input from hdr records to standard logic vectors and join them
signal ETH_TX 			: ETH_HDR;
signal IPV4_TX 			: IPV4_HDR;
signal UDP_TX 			: UDP_HDR;
signal TX_HDR_slv 		: std_logic_vector(c_ETH_HLEN + c_IPV4_HLEN + c_UDP_HLEN-1 downto 0);
alias  ETH_TX_slv 		: std_logic_vector(c_ETH_HLEN-1 downto 0) 	is TX_HDR_slv(c_ETH_HLEN + c_IPV4_HLEN + c_UDP_HLEN-1 downto c_IPV4_HLEN + c_UDP_HLEN);
alias  IPV4_TX_slv 		: std_logic_vector(c_IPV4_HLEN-1 downto 0) 	is TX_HDR_slv(c_IPV4_HLEN + c_UDP_HLEN-1 downto c_UDP_HLEN);
alias  UDP_TX_slv 		: std_logic_vector(c_UDP_HLEN-1 downto 0) 	is TX_HDR_slv(c_UDP_HLEN-1 downto 0);

--shift register output and control signals
signal s_out 			: std_logic_vector(31 downto 0);
signal sh_hdr_en 		: std_logic;
signal ld_hdr		: std_logic;
signal counter_ouput	: unsigned(7 downto 0);

signal chksum_empty 	: std_logic;
signal hdr_empty 	: std_logic;
signal chksum_full 	: std_logic;
signal hdr_full 	: std_logic;


-- forking the bus
type stmux is (HEADER, PAYLOAD);
signal state_mux		: stmux := HEADER;
signal  TX_hdr_o 		: wb16_master_out;	--! Wishbone master output lines
signal  wb_payload_stall_o 		: wb32_slave_out;
signal 	stalled  		: std_logic;

-- IP checksum generator
signal 	counter_chksum	: unsigned(7 downto 0);
signal 	p_chk_vals		: std_logic_vector(95 downto 0);
signal  s_chk_vals		: std_logic_vector(15 downto 0);
signal 	IP_chk_sum		: std_logic_vector(15 downto 0);
signal  sh_chk_en 		: std_logic;         
signal  calc_chk_en		: std_logic;
signal  ld_p_chk_vals	: std_logic;            --parallel load
signal 	chksum_done 	: std_logic;

signal DEBUG_cmp_chksum : IPV4_HDR;

signal PISO_STALL : std_logic;

function calc_ip_chksum(input : IPV4_HDR)
return IPV4_HDR is
    variable tmp : unsigned(c_IPV4_HLEN-1 downto 0); 
	variable output : IPV4_HDR;
	variable tmp_sum : unsigned(31 downto 0) := (others => '0');
	variable tmp_slice : unsigned(15 downto 0);
	begin
 		tmp := unsigned(to_std_logic_vector(input));
		for i in c_IPV4_HLEN/16-1 downto 0 loop 
			tmp_slice := tmp((i+1)*16-1 downto i*16);
			tmp_sum := tmp_sum + (x"0000" & tmp_slice); 
		end loop;
		tmp_sum := (x"0000" & tmp_sum(15 downto 0)) + (x"0000" + tmp_sum(31 downto 16));
		output.SUM := std_logic_vector(NOT(tmp_sum(15 downto 0) + tmp_sum(31 downto 16)));
	return output;
end function calc_ip_chksum; 

begin

ETH_TX_slv	<= TO_STD_LOGIC_VECTOR(ETH_TX);
IPV4_TX_slv	<= TO_STD_LOGIC_VECTOR(IPV4_TX);
UDP_TX_slv	<= TO_STD_LOGIC_VECTOR(UDP_TX);


MUX_TX : with state_mux select 
TX_master_o	<=  conv_B	when PAYLOAD,
				TX_hdr_o 						when others;

MUX_WB : with state_mux select
wb_slave_o <=	wb_payload_stall_o when HEADER,
							conv_A when others; 
				

MUX_PISO : with state_mux select
PISO_STALL <=	'1' when HEADER,
				TX_master_i.STALL when others;
			
				
shift_hdr_chk_sum : piso_flag generic map( 96, 16)
port map ( d_i         => p_chk_vals,
           q_o         => s_chk_vals,
           clk_i       => clk_i,
           nRST_i      => nRST_i,
           en_i        => sh_chk_en,
           ld_i       	=> ld_p_chk_vals, 
					 full_o	   => chksum_full,
					 empty_o		=> chksum_empty
);

p_chk_vals		<= x"C511" & IPV4_TX.SRC & IPV4_TX.DST & IPV4_TX.TOL;

chksum_generator: EB_checksum port map ( clk_i  => clk_i,
                              nRst_i => nRst_i,
                              en_i   => calc_chk_en,
                              data_i => s_chk_vals,
                              done_o => chksum_done,
                              sum_o  => IP_chk_sum );

				




Shift_out: piso_flag generic map (c_ETH_HLEN + c_IPV4_HLEN + c_UDP_HLEN, 16)
                        port map ( d_i         => TX_HDR_slv ,
                                   q_o         => TX_hdr_o.DAT,
                                   clk_i       => clk_i,
                                   nRST_i      => nRST_i,
                                   en_i        => sh_hdr_en ,
                                   ld_i       	=> ld_hdr, 
								   full_o	   => hdr_full,
									empty_o		=> hdr_empty
								   );




			
			
-- convert streaming input from 16 to 32 bit data width
uut: WB_bus_adapter_streaming_sg generic map (   g_adr_width_A => 32,
                                                 g_adr_width_B => 32,
                                                 g_dat_width_A => 32,
                                                 g_dat_width_B => 16,
                                                 g_pipeline    =>  3)
                                      port map ( clk_i         => clk_i,
                                                 nRst_i        => nRst_i,
                                                 A_CYC_i       => wb_slave_i.CYC,
                                                 A_STB_i       => wb_slave_i.STB,
                                                 A_ADR_i       => wb_slave_i.ADR,
                                                 A_SEL_i       => wb_slave_i.SEL,
                                                 A_WE_i        => wb_slave_i.WE,
                                                 A_DAT_i       => wb_slave_i.DAT,
                                                 A_ACK_o       => conv_A.ACK,
                                                 A_ERR_o       => conv_A.ERR,
                                                 A_RTY_o       => conv_A.RTY,
                                                 A_STALL_o     => conv_A.STALL,
                                                 A_DAT_o       => conv_A.DAT,
                                                 B_CYC_o       => conv_B.CYC,
                                                 B_STB_o       => conv_B.STB,
                                                 B_ADR_o       => conv_B.ADR,
                                                 B_SEL_o       => conv_B.SEL,
                                                 B_WE_o        => conv_B.WE,
                                                 B_DAT_o       => conv_B.DAT,
                                                 B_ACK_i       => TX_master_i.ACK,
                                                 B_ERR_i       => TX_master_i.ERR,
                                                 B_RTY_i       => TX_master_i.RTY,
                                                 B_STALL_i     => PISO_STALL,
                                                 B_DAT_i       => TX_master_i.DAT); 





TX_hdr_o.STB <= '1' when state_tx = HDR_SEND AND hdr_empty = '0'
else '0';


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
			--TX_hdr_o.STB 			<= '0';
			TX_hdr_o.WE 			<= '1';
			TX_hdr_o.ADR 			<= (others => '0');
			TX_hdr_o.SEL  			<= (others => '1');
			
			wb_payload_stall_o.STALL <= '1';
			wb_payload_stall_o.ACK 	<= '0';
			wb_payload_stall_o.DAT 	<= (others => '0');
			wb_payload_stall_o.ERR 	<= '0';
			wb_payload_stall_o.RTY 	<= '0';
			
			state_mux				<= HEADER;
			
			sh_hdr_en 				<= '0';
			ld_hdr 				<= '0';
			stalled 				<= '0';
			counter_ouput 			<= (others => '0');
			counter_chksum			<= (others => '0');
			 -- prepare chk sum field_tx_hdr, fill in reply IP and TOL field_tx_hdr when available
			ld_p_chk_vals			<= '0';
			sh_chk_en				<= '0';
			calc_chk_en 			<= '0';
		else
			
			--TX_hdr_o.STB 			<= '0';
			
			ld_hdr 				<= '0';
			sh_hdr_en 	  			<= '0';
			
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
											UDP_TX.MLEN		<= std_logic_vector(unsigned(TOL_i)-((c_ETH_HLEN + c_IPV4_HLEN)/8));	
											UDP_TX.DST_PORT	<= reply_PORT_i;
											ld_p_chk_vals	<= '1';
											state_tx 		<= CALC_CHKSUM;		
										end if;
				
				when CALC_CHKSUM	=>	if(chksum_empty = '0') then
											sh_chk_en <= '1';
											calc_chk_en 	<= '1';
											counter_chksum 	<= counter_chksum +1;
										else
											if(chksum_done = '1') then
												DEBUG_cmp_chksum <= calc_ip_chksum(IPV4_TX);
												IPV4_TX.SUM	<= IP_chk_sum;
												ld_hdr 	<= '1';
												state_tx 	<= WAIT_SEND_REQ;
											end if;
										end if;	
				
				when WAIT_SEND_REQ	=>	state_mux	<= HEADER;	
										if(wb_slave_i.CYC = '1') then
											TX_hdr_o.CYC 	<= '1';
											--TX_hdr_o.STB 	<= '1';
											sh_hdr_en 		<= '1';
											state_tx 		<= HDR_SEND;
										end if;
										
				
				when HDR_SEND		=> 	if(hdr_empty = '0') then
											--TX_hdr_o.STB <= '1';
											if(TX_master_i.STALL = '0') then
												
												sh_hdr_en 	<= '1';
												counter_ouput <= counter_ouput +1;	
											end if;											
										
											-- if(TX_master_i.STALL = '1') then
												-- stalled 	<= '1';
												
											-- else
												-- --TX_hdr_o.STB <= '1';
												-- if(stalled  = '1') then
													-- stalled  <= '0';
												-- else
													-- sh_TX_en <= '1';
													-- counter_ouput <= counter_ouput +1;
												-- end if;
											-- end if;	
										else
											--TX_hdr_o.STB <= '0';
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