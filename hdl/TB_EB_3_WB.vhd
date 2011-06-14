--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wb32_package.all;
use work.wb16_package.all;


entity TB_EB3 is 
end TB_EB3;

architecture behavioral of TB_EB3 is

component wb_timer 
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wb32_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wb32_slave_in;    --! 

		signal_out	   : out std_logic_vector(31 downto 0);			
		
		compmatchA_o		: out	std_logic;
		n_compmatchA_o		: out	std_logic;
		
		compmatchB_o		: out	std_logic;
		n_compmatchB_o		: out	std_logic
    );

end component;

component packet_capture is
generic(filename : string := "123.pcap";  wordsize : natural := 32);
port(
	clk_i    		: in    std_logic;                                        --clock
    nRST_i   		: in   	std_logic;

	TOL_i		: in 	std_logic_vector(15 downto 0);
	
	sample_i		: in   	std_logic;
	valid_i			: in   	std_logic;
	data_i			: in	std_logic_vector(wordsize-1 downto 0)
);	
end component;

component EB_CORE is 
port
(
	clk_i           	: in    std_logic;   --! clock input
	nRst_i				: in 	std_logic;
	
	-- slave RX streaming IF -------------------------------------
	slave_RX_CYC_i		: in 	std_logic;						--
	slave_RX_STB_i		: in 	std_logic;						--
	slave_RX_DAT_i		: in 	std_logic_vector(15 downto 0);	--	
	slave_RX_STALL_o	: out 	std_logic;						--						
	slave_RX_ERR_o		: out 	std_logic;						--
	slave_RX_ACK_o		: out 	std_logic;						--
	--------------------------------------------------------------
	
	-- master TX streaming IF ------------------------------------
	master_TX_CYC_o		: out 	std_logic;						--
	master_TX_STB_o		: out 	std_logic;						--
	master_TX_DAT_o		: out 	std_logic_vector(15 downto 0);	--	
	master_TX_STALL_i	: in 	std_logic;						--						
	master_TX_ERR_i		: in 	std_logic;						--
	master_TX_ACK_i		: in 	std_logic;						--
	--------------------------------------------------------------

	-- master IC IF ----------------------------------------------
	master_IC_i			: in	wb32_master_in;
	master_IC_o			: out	wb32_master_out
	--------------------------------------------------------------
	
);
end component;

component EB_TX_CTRL is 
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
end component;


----------------------------------------------------------------------------------
constant c_PACKETS  : natural := 1;
constant c_CYCLES   : natural := 2;
constant c_RDS      : natural := 4;
constant c_WRS      : natural := 4;

constant c_READ_START 	: unsigned(31 downto 0) := x"0000000C";
constant c_REPLY_START	: unsigned(31 downto 0) := x"ADD3E550";

constant c_WRITE_START 	: unsigned(31 downto 0) := x"00000010";
constant c_WRITE_VAL	: unsigned(31 downto 0) := x"0000000F";
----------------------------------------------------------------------------------







signal s_clk_i : std_logic := '0';
signal s_nRST_i : std_logic := '0';
signal stop_the_clock : boolean := false;
signal firstrun : boolean := true;
constant clock_period: time := 8 ns;

	--Eth MAC WB Streaming signals
signal s_slave_RX_stream_i		: wb32_slave_in;
signal s_slave_RX_stream_o		: wb32_slave_out;
signal s_master_TX_stream_i		: wb16_master_in;
signal s_master_TX_stream_o		: wb16_master_out;

signal s_txctrl_i		: wb16_master_in;
signal s_txctrl_o		: wb16_master_out;
signal s_ebcore_i		: wb16_slave_in;
signal s_ebcore_o		: wb16_slave_out;

signal s_byte_count_i			: unsigned(15 downto 0);
signal s_byte_count_o			: unsigned(15 downto 0);
	
	--WB IC signals
signal s_master_IC_i			: wb32_master_in;
signal s_master_IC_o			: wb32_master_out;

signal s_wb_slave_o				: wb32_slave_out;
signal s_wb_slave_i				: wb32_slave_in;

signal LEN		: natural := (1+(c_CYCLES * (1 + c_RDS/c_RDS + c_RDS + c_WRS/c_WRS + c_WRS)))*4; --x4 because it's bytes
signal TOL		: std_logic_vector(15 downto 0);

signal RX_EB_HDR : EB_HDR;
signal RX_EB_CYC : EB_CYC;

signal s_oc_a : std_logic;
signal s_oc_an : std_logic;
signal s_oc_b : std_logic;
signal s_oc_bn : std_logic;

type FSM is (INIT, INIT_DONE, PACKET_HDR, CYCLE_HDR, RD_BASE_ADR, RD, WR_BASE_ADR, WR, CYC_DONE, PACKET_DONE, DONE);
signal state : FSM := INIT;	

signal stall : std_logic := '0';

signal capture : std_logic := '1';

signal pcap_in_wren : std_logic := '0';
signal pcap_out_wren : std_logic := '0';

signal s_signal_out : std_logic_vector(31 downto 0);

begin

TOL <= std_logic_vector(to_unsigned(LEN+28, 16));

  core: EB_CORE port map ( clk_i             => s_clk_i,
                          nRst_i            => s_nRst_i,
                          slave_RX_CYC_i    => s_ebcore_i.CYC,
                          slave_RX_STB_i    => s_ebcore_i.STB,
                          slave_RX_DAT_i    => s_ebcore_i.DAT,
                          slave_RX_STALL_o  => s_ebcore_o.STALL,
                          slave_RX_ERR_o    => s_ebcore_o.ERR,
                          slave_RX_ACK_o    => s_ebcore_o.ACK,
                          master_TX_CYC_o   => s_master_TX_stream_o.CYC,
                          master_TX_STB_o   => s_master_TX_stream_o.STB,
                          master_TX_DAT_o   => s_master_TX_stream_o.DAT,
                          master_TX_STALL_i => s_master_TX_stream_i.STALL,
                          master_TX_ERR_i   => s_master_TX_stream_i.ERR,
                          master_TX_ACK_i   => s_master_TX_stream_i.ACK,
                          master_IC_i       => s_master_IC_i,
                          master_IC_o       => s_master_IC_o );

 

s_ebcore_o		<= wb16_slave_out(s_txctrl_i);
s_ebcore_i		<= wb16_slave_in(s_txctrl_o);


 
 TXCTRL : EB_TX_CTRL
port map
(
		clk_i             => s_clk_i,
		nRST_i            => s_nRst_i, 
		
		--Eth MAC WB Streaming signals
		wb_slave_i	=> s_slave_RX_stream_i,
		wb_slave_o	=> s_slave_RX_stream_o,

		--TX_master_slv_o  =>        s_TX_master_slv_o,	--! Wishbone master output lines
		--TX_master_slv_i  =>        s_TX_master_slv_i,    --! 
		TX_master_o     =>	s_txctrl_o,
		TX_master_i     =>  s_txctrl_i,  --!
		
		reply_MAC_i			=> x"BEE0BEE1BEE2", 
		reply_IP_i			=> x"FFFFFFFF",
		reply_PORT_i		=> x"EBD0",

		TOL_i				=> TOL,
		
		valid_i				=> '1'
		
);




WB_DEV : wb_timer
generic map(g_cnt_width => 32) 
port map(
		clk_i	=> s_clk_i,
		nRst_i	=> s_nRst_i,
		
		wb_slave_o     	=> s_wb_slave_o,	
		wb_slave_i     	=> s_wb_slave_i,  
		signal_out	   => s_signal_out,	
		compmatchA_o	=> s_oc_a,
		n_compmatchA_o	=> s_oc_an,
		compmatchB_o	=> s_oc_b,
		n_compmatchB_o  => s_oc_bn
    );


	s_master_IC_i <= wb32_master_in(s_wb_slave_o);
	s_wb_slave_i <= wb32_slave_in(s_master_IC_o);

	
pcapin : packet_capture
generic map(filename => "eb_input2.pcap", wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,

	TOL_i	=> TOL,
	
	sample_i		=> capture,
	valid_i			=> pcap_in_wren,
	data_i			=> s_txctrl_o.DAT
);

	pcap_in_wren <= (s_ebcore_i.STB AND (NOT s_ebcore_o.STALL));

pcapout : packet_capture
generic map(filename => "eb_output.pcap",  wordsize => 16) 
port map(
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,

	TOL_i	=> TOL,
	
	sample_i		=> capture,
	valid_i			=> pcap_out_wren,
	data_i			=> s_master_TX_stream_o.DAT
);		

pcap_out_wren <= (s_master_TX_stream_o.STB AND (NOT s_master_TX_stream_i.STALL));


    clkGen : process
    begin 
      while not stop_the_clock loop
         s_clk_i <= '0', '1' after clock_period / 2;
         wait for clock_period;
      end loop;
	  report "simulation end" severity failure;
    end process clkGen;
    
    rx_packet : process
    
	
	    variable i : integer := 0;
	    
		variable packets : natural := 0;
		variable cycles : natural := 0;
		variable rds : natural := 0;
		variable wrs : natural := 0;
    
    begin
        wait until rising_edge(s_clk_i);
		
		
					
		
				  
		s_slave_RX_stream_i.STB <= '0'; 		
		if(s_slave_RX_stream_o.STALL = '0' OR firstrun) then
			if(stall = '0') then
				--s_slave_RX_stream_i.STB <= '1'; 
				case state is
					when INIT 			=> 	
											packets := c_PACKETS;
											cycles 	:= c_CYCLES;
											rds 	:= c_RDS;
											wrs 	:= c_WRS;
											--s_nRST_i 			<= '0';
											RX_EB_HDR			<=	init_EB_HDR;
											RX_EB_CYC.RESERVED2	<=	(others => '0');
											RX_EB_CYC.RESERVED3	<=	(others => '0');
											RX_EB_CYC.RD_FIFO	<=	'0';
											RX_EB_CYC.RD_CNT	<=	to_unsigned(rds, 12);
											RX_EB_CYC.WR_FIFO	<=	'0';
											RX_EB_CYC.WR_CNT	<=	to_unsigned(wrs, 12);
											
											s_master_TX_stream_i <=   (
												ACK   => '0',
												ERR   => '0',
												RTY   => '0',
												STALL => '0',
												DAT   => (others => '0'));
										 
											s_slave_RX_stream_i <=   (
												CYC => '0',
												STB => '0',
												ADR => (others => '0'),
												SEL => (others => '1'),
												WE  => '1',
												DAT => (others => '0'));
											
											s_byte_count_i <= to_unsigned(LEN, 16);
											s_slave_RX_stream_i.CYC <= '0';
											s_slave_RX_stream_i.STB <= '0';
											
											
											
											state <= INIT_DONE;
					
					when INIT_DONE		=>	
					           firstrun <= false;
					           s_slave_RX_stream_i.CYC <= '1';
											s_nRST_i      			<= '1';
											state 					<= PACKET_HDR;
					
					when PACKET_HDR 	=> 	s_slave_RX_stream_i.CYC <= '1';
											s_slave_RX_stream_i.STB <= '1';
											s_slave_RX_stream_i.DAT <= to_std_logic_vector(RX_EB_HDR);
											--cycles :=  cycles +1;
											state 					<= CYCLE_HDR;
											
					when CYCLE_HDR 		=>	s_slave_RX_stream_i.STB <= '1';
											s_slave_RX_stream_i.DAT <= to_std_logic_vector(RX_EB_CYC);
											--rds :=  rds +1;
											--wrs := wrs +1;
											
											if(RX_EB_CYC.RD_CNT > 0) then
												state <= RD_BASE_ADR;
											else
												state <= RD;
											end if;
											
					when RD_BASE_ADR 	=>  s_slave_RX_stream_i.STB <= '1';
											s_slave_RX_stream_i.DAT <= std_logic_vector(c_REPLY_START);
											state <= RD;
					
					when RD 			=>  if(RX_EB_CYC.RD_CNT > 0) then
												s_slave_RX_stream_i.STB <= '1';
												s_slave_RX_stream_i.DAT <= std_logic_vector(c_READ_START + (resize((c_RDS - RX_EB_CYC.RD_CNT)*4, 32)));
												RX_EB_CYC.RD_CNT <= RX_EB_CYC.RD_CNT-1;
											else											
												if(RX_EB_CYC.WR_CNT > 0) then
													state <= WR_BASE_ADR;
													--s_slave_RX_stream_i.STB <= '1';
												else
													state <= CYC_DONE;
												end if;
											end if;
											
					when WR_BASE_ADR 	=>  s_slave_RX_stream_i.STB <= '1';
											s_slave_RX_stream_i.DAT <= std_logic_vector(c_WRITE_START);
											state <= WR;
					
					when WR 			=>  if(RX_EB_CYC.WR_CNT > 0) then
												s_slave_RX_stream_i.STB <= '1';
												s_slave_RX_stream_i.DAT <= std_logic_vector(c_WRITE_VAL + resize(RX_EB_CYC.WR_CNT, 32));
												RX_EB_CYC.WR_CNT <= RX_EB_CYC.WR_CNT-1;
											else											
												state <= CYC_DONE;
											end if;
					
					when CYC_DONE 		=>		cycles := cycles -1;
												if(cycles > 0) then
												
												
												-- if(rds = 3) then 
													-- RX_EB_CYC.RD_FIFO <= '1';
												-- else	
													-- RX_EB_CYC.RD_FIFO <= '0';
												-- end if;
												
												-- if(wrs = 3) then 
													-- RX_EB_CYC.WR_FIFO <= '1';
												-- else	
													-- RX_EB_CYC.WR_FIFO <= '0';
												-- end if;
												rds 	:= c_RDS;
												wrs 	:= c_WRS;
												
												RX_EB_CYC.RD_CNT 	<= to_unsigned(c_RDS, 12);
												RX_EB_CYC.WR_CNT 	<= to_unsigned(c_WRS, 12);
												state <= CYCLE_HDR;
											else
												state <= PACKET_DONE;
											end if;
											
					when PACKET_DONE 	=>	s_slave_RX_stream_i.CYC <= '0';
											packets := packets -1;
											if(packets > 0) then
												
												cycles 	:= c_CYCLES;
												state <= DONE;
												firstrun <= true;
											else
												state <= DONE;
											end if;
					when DONE			=>   wait for 50*clock_period;
											capture <= '0';	
					                 stop_the_clock <= TRUE;
											
																				
					
				end case;
		
			else
				stall <= '0';
				s_slave_RX_stream_i.STB <= '1';
					
			end if;		
		else
			if(s_slave_RX_stream_i.STB = '1') then
				stall <= '1';
			end if;	
		end if;
		
		
    end process rx_packet;
	


end architecture behavioral;   


