--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wishbone_package.all;

entity TB_EB3 is 
end TB_EB3;

architecture behavioral of TB_EB3 is

component eb_2_wb_converter is 
port(
	clk_i	: in std_logic;
	nRst_i	: in std_logic;

	--Eth MAC WB Streaming signals
	slave_RX_stream_i	: in	wishbone_slave_in;
	slave_RX_stream_o	: out	wishbone_slave_out;

	master_TX_stream_i	: in	wishbone_master_in;
	master_TX_stream_o	: out	wishbone_master_out;

	byte_count_rx_i			: in unsigned(15 downto 0);
	byte_count_tx_o			: out unsigned(15 downto 0);
	
	--WB IC signals
	master_IC_i	: in	wishbone_master_in;
	master_IC_o	: out	wishbone_master_out
);
end component;



component wb_timer
generic(g_cnt_width : natural := 32);	-- MAX WIDTH 32
 port(
		clk_i    		: in    std_logic;                                        --clock
        nRST_i   		: in   	std_logic;
		
		wb_slave_o     : out   wishbone_slave_out;	--! Wishbone master output lines
		wb_slave_i     : in    wishbone_slave_in;    --! 

		compmatchA_o		: out	std_logic;
		compmatchB_o		: out	std_logic
		
    );

end component;



signal s_clk_i : std_logic := '0';
signal s_nRST_i : std_logic;
signal stop_the_clock : boolean := false;
signal firstrun : std_logic := '1';
constant clock_period: time := 8 ns;

	--Eth MAC WB Streaming signals
signal s_slave_RX_stream_i		: wishbone_slave_in;
signal s_slave_RX_stream_o		: wishbone_slave_out;
signal s_master_TX_stream_i		: wishbone_master_in;
signal s_master_TX_stream_o		: wishbone_master_out;
signal s_byte_count_i			: unsigned(15 downto 0);
signal s_byte_count_o			: unsigned(15 downto 0);
	
	--WB IC signals
signal s_master_IC_i			: wishbone_master_in;
signal s_master_IC_o			: wishbone_master_out;

signal s_wb_slave_o				: wishbone_slave_out;
signal s_wb_slave_i				: wishbone_slave_in;

constant c_PACKETS  : natural := 2;
constant c_CYCLES   : natural := 2;
constant c_RDS      : natural := 2;
constant c_WRS      : natural := 2;

signal LEN		: natural := (1+(c_CYCLES * (1 + ((1*c_RDS) + c_RDS) + ((1*c_WRS) + c_WRS))))*4; --x4 because it's bytes

signal RX_EB_HDR : EB_HDR;
signal RX_EB_CYC : EB_CYC;

signal s_oc_a : std_logic;
signal s_oc_b : std_logic;

type FSM is (INIT, INIT_DONE, PACKET_HDR, CYCLE_HDR, RD_BASE_ADR, RD, WR_BASE_ADR, WR, CYC_DONE, PACKET_DONE, DONE);
signal state : FSM := INIT;	

signal stall : std_logic := '0';

begin

DUT : eb_2_wb_converter
port map(
       --general
	clk_i	=> s_clk_i,
	nRst_i	=> s_nRst_i,

	--Eth MAC WB Streaming signals
	slave_RX_stream_i	=> s_slave_RX_stream_i,
	slave_RX_stream_o	=> s_slave_RX_stream_o,

	master_TX_stream_i	=> s_master_TX_stream_i,
	master_TX_stream_o	=> s_master_TX_stream_o,

  byte_count_rx_i		=> s_byte_count_i,
	byte_count_tx_o		=> s_byte_count_o,
	
	--WB IC signals
	master_IC_i			=> s_master_IC_i,
	master_IC_o			=> s_master_IC_o
);  

WB_DEV : wb_timer
generic map(g_cnt_width => 32) 
port map(
		clk_i	=> s_clk_i,
		nRst_i	=> s_nRst_i,
		
		wb_slave_o     	=> s_wb_slave_o,	
		wb_slave_i     	=> s_wb_slave_i,  

		compmatchA_o	=> s_oc_a,
		compmatchB_o	=> s_oc_b
		
    );


	s_master_IC_i <= wishbone_master_in(s_wb_slave_o);
	s_wb_slave_i <= wishbone_slave_in(s_master_IC_o);

	

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
		if(s_slave_RX_stream_o.STALL = '0') then
			if(stall = '0') then
				--s_slave_RX_stream_i.STB <= '1'; 
				case state is
					when INIT 			=> 	packets := c_PACKETS;
											cycles 	:= c_CYCLES;
											rds 	:= c_RDS;
											wrs 	:= c_WRS;
											s_nRST_i 			<= '0';
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
					
					when INIT_DONE		=>	s_slave_RX_stream_i.CYC <= '1';
											s_nRST_i      			<= '1';
											state 					<= PACKET_HDR;
					
					when PACKET_HDR 	=> 	s_slave_RX_stream_i.STB <= '1';
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
											s_slave_RX_stream_i.DAT <= x"AAAA0000";
											state <= RD;
					
					when RD 			=>  if(RX_EB_CYC.RD_CNT > 0) then
												s_slave_RX_stream_i.STB <= '1';
												s_slave_RX_stream_i.DAT <= std_logic_vector(to_unsigned(12,32) + (resize((c_RDS - RX_EB_CYC.RD_CNT)*4, 32)));
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
											s_slave_RX_stream_i.DAT <= x"0000000C";
											state <= WR;
					
					when WR 			=>  if(RX_EB_CYC.WR_CNT > 0) then
												s_slave_RX_stream_i.STB <= '1';
												s_slave_RX_stream_i.DAT <= std_logic_vector(resize(RX_EB_CYC.WR_CNT, 32));
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
												
												RX_EB_CYC.RD_CNT 	<= to_unsigned(rds, 12);
												RX_EB_CYC.WR_CNT 	<= to_unsigned(wrs, 12);
												state <= CYCLE_HDR;
											else
												state <= DONE;
											end if;
											
					when PACKET_DONE 	=>	s_slave_RX_stream_i.CYC <= '0';
											packets := packets -1;
											if(packets > 0) then
												
												cycles 	:= c_CYCLES;
												state <= PACKET_HDR;
											else
												state <= DONE;
											end if;
					when DONE			=>   wait for 15*clock_period;
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
	
	-- wb : process
    
	-- variable ccount : unsigned(31 downto 0) := x"A0000000";
	
	-- begin
        
		
		
		-- wait until rising_edge(s_clk_i);
        -- if(s_nRST_i = '0') then
          	-- s_master_IC_i <=   (
				-- ACK   => '0',
				-- ERR   => '0',
				-- RTY   => '0',
				-- STALL => '0',
				-- DAT   => (others => '0'));
				
        -- else  
			-- s_master_ic_i.ACK <= s_master_ic_o.STB; 
		    
			-- if(s_master_ic_o.STB = '1' AND s_master_ic_o.WE = '0') then
				-- ccount := ccount + 1;
				-- s_master_ic_i.DAT <= std_logic_vector(ccount);
			-- end if;		
		-- end if;
    -- end process wb;

end architecture behavioral;   


