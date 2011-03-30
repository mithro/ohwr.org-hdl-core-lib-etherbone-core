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

	byte_count_i			: in unsigned(15 downto 0);
	byte_count_o			: out unsigned(15 downto 0);
	
	--WB IC signals
	master_IC_i	: in	wishbone_master_in;
	master_IC_o	: out	wishbone_master_out
);


signal s_clk : std_logic := '0';
signal s_nRST : std_logic;
signal stop_the_clock : boolean := false;
constant clock_period: time := 8 ns

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

	byte_count_i		=> s_byte_count_i,
	byte_count_o		=> s_byte_count_o,
	
	--WB IC signals
	master_IC_i			=> s_master_IC_i,
	master_IC_o			=> s_master_IC_o
);  




    clkGen : process
    begin 
      while not stop_the_clock loop
         s_clk <= '0', '1' after clock_period / 2;
         wait for clock_period;
      end loop;
    end process clkGen;
    
    rx_packet : process
    begin
        if(firstrun = '1') then
			firstrun <= '0';
			wait until rising_edge(s_clk);
			s_nRST      <= '0';
		   
			s_master_IC_i <=   (
				ACK   => '0',
				ERR   => '0',
				RTY   => '0',
				STALL => '0',
				DAT   => (others => '0'));
		   
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
           s_nRST      <= '1';
		   wait for clock_period;
		   
		   
           --------------------------------------------------------------
           -- SET 1ST DEGREE VECTOR
           --------------------------------------------------------------
           
		   
		   
		   
           
           --wait until falling_edge(s_ACK_o);
		   
		   
           
        else
           stop_the_clock <= true;
        end if;
          
    
    end process rx_packet;
	
	wb : process
    begin
        if(firstrun = '1') then
           firstrun <= '0';
           wait until rising_edge(s_clk);
           s_nRST      <= '0';
           wait for clock_period;
           s_nRST      <= '1';
           --------------------------------------------------------------
           -- SET 1ST DEGREE VECTOR
           --------------------------------------------------------------
           
		   
		   
		   
           wait for clock_period;
           wait until falling_edge(s_ACK_o);
           
        else
           stop_the_clock <= true;
        end if;
          
    
    end process main;
end architecture behavioral; 
end architecture behavioral;   


