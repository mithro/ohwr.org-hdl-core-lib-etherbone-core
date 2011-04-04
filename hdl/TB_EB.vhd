--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.EB_HDR_PKG.all;
use work.wishbone_package.all;

entity TB_EB is 
end TB_EB;

architecture behavioral of TB_EB is

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

constant DWORD : natural := 32;

signal RX_EB_HDR : EB_HDR;
signal RX_EB_CYC1 : EB_CYC;
signal RX_EB_CYC1_DATA_READ : std_logic_vector((1+6)*DWORD-1 downto 0);
signal RX_EB_CYC1_DATA_WRITE  : std_logic_vector((1+3)*DWORD-1 downto 0);
	
signal EB_LEN : natural :=  32 + 32		+ RX_EB_CYC1_DATA_READ'length + RX_EB_CYC1_DATA_WRITE'length;
	
signal EB_PACKET : std_logic_vector(EB_LEN-1 downto 0);

subtype EB_TEST is std_logic_vector(31 downto 0);
type EB_T is array(49 downto 0) of EB_TEST;	
signal TEST_RX : EB_T;
signal TEST_WB : EB_T;


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




    clkGen : process
    begin 
      while not stop_the_clock loop
         s_clk_i <= '0', '1' after clock_period / 2;
         wait for clock_period;
      end loop;
	  report "End of simulation" severity Failure; 
	  
    end process clkGen;
    
    rx_packet : process
    
	
	    variable i : integer := 0;
		variable stall : std_logic := '0';
    
    begin
        if(firstrun = '1') then
			firstrun <= '0';
			wait until rising_edge(s_clk_i);
			s_nRST_i      <= '0';
			
			RX_EB_HDR				<=	init_EB_HDR;
			RX_EB_CYC1.RESERVED2	<=	(others => '0');
			RX_EB_CYC1.RESERVED3	<=	(others => '0');
			RX_EB_CYC1.RD_FIFO	<=	'0';
			RX_EB_CYC1.RD_CNT	 <=	x"006";
			RX_EB_CYC1.WR_FIFO	<=	'0';
			RX_EB_CYC1.WR_CNT	 <=	x"003";
			
			RX_EB_CYC1_DATA_READ  	<=  (x"AAAAAAAA" & x"5EADAAA0" & x"5EADAAA1" & x"5EADAAA2" & x"5EADAAA3" & x"5EADAAA4" & x"5EADAAA5");  
			RX_EB_CYC1_DATA_WRITE 	<=	(x"A0000000" & x"D15EA5ED" & x"DEADBEEF" & x"FEED5A11");  
			
			
			
		   
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
				SEL => (others => '0'),
				WE  => '0',
				DAT => (others => '0'));
			
			s_byte_count_i <= (others => '0');
			wait for clock_period;
			
			s_nRST_i      <= '1';
			EB_PACKET <= to_std_logic_vector(RX_EB_HDR) & to_std_logic_vector(RX_EB_CYC1) & RX_EB_CYC1_DATA_READ & RX_EB_CYC1_DATA_WRITE;
			
			wait for clock_period;
		   
			 s_slave_RX_stream_i <=   (
				CYC => '0',
				STB => '0',
				ADR => (others => '0'),
				SEL => (others => '1'),
				WE  => '1',
				DAT => (others => '0'));
		   
		    I := (EB_PACKET'LENGTH / 32)-1; 
			 s_slave_RX_stream_i.CYC <= '1';
			 s_slave_RX_stream_i.STB <= '1';
			while I >= 0 loop
					
				s_slave_RX_stream_i.DAT <= EB_PACKET((I+1)*32-1 downto I*32);
				wait for clock_period;		
				
				  
				
				if(s_slave_RX_stream_o.STALL = '0') then
					s_slave_RX_stream_i.STB <= '1';
					if(stall = '0') then
					I := I-1;
					else
					 stall := '0';
					end if;
					else
					   stall := '1';
					   s_slave_RX_stream_i.STB <= '0'; 
					wait for clock_period;	
				end if;
				
			end loop;
			 s_slave_RX_stream_i.CYC <= '0';
			 s_slave_RX_stream_i.STB <= '0';	
           --wait until falling_edge(s_ACK_o);
		   
		   wait for 5*clock_period;
         
           stop_the_clock <= true;
           wait for clock_period;
        end if;
          
    wait for clock_period;
    end process rx_packet;
	
	wb : process
    
	variable ccount : unsigned(31 downto 0) := (others => '0');
	variable j : natural := TEST_RX'length; 
	
	variable k : natural := TEST_WB'length;
	
	
	begin
        
		
		
		wait until rising_edge(s_clk_i);
        if(s_nRST_i = '0') then
          	s_master_IC_i <=   (
				ACK   => '0',
				ERR   => '0',
				RTY   => '0',
				STALL => '0',
				DAT   => (others => '0'));
				
        else  
			if(s_master_TX_stream_o.STB = '1')then
				J := J -1;
				TEST_RX(J) <= s_master_TX_stream_o.DAT;
			end if;
			
			if(s_master_IC_o.STB = '1')then
				K := K -1;
				TEST_WB(K) <= s_master_IC_o.ADR;
			end if;

				
			
			s_master_ic_i.ACK <= s_master_ic_o.STB; 
		    s_master_ic_i.DAT <= std_logic_vector(ccount);
			if(s_master_ic_o.STB = '1') then
				ccount := ccount + 1;
			end if;		
		end if;
    end process wb;

end architecture behavioral;   


