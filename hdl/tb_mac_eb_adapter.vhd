library IEEE;
use IEEE.Std_logic_1164.all;
use IEEE.Numeric_Std.all;
use work.wishbone_package.all;


entity mac_eb_adapter_tb is
end;

architecture bench of mac_eb_adapter_tb is

  component mac_eb_adapter 
   port(
  		clk_i    	: in    std_logic;
          nRST_i   	: in   	std_logic;
  		wb_slave_o  : out   wishbone_slave_out;	
  		wb_slave_i  : in    wishbone_slave_in;    
  		TX_RAM_o    : out   wishbone_master_out;	
  		TX_RAM_i    : in    wishbone_master_in;     
  		RX_RAM_o    : out   wishbone_master_out;	
  		RX_RAM_i    : in    wishbone_master_in;   
  		RX_EB_o		: out	wishbone_master_out;
  		RX_EB_i		: in	wishbone_master_in;
  		TX_EB_i		: in	wishbone_slave_in;
  		TX_EB_o		: out	wishbone_slave_out;
  		IRQ_tx_done_o	: out	std_logic;
  		IRQ_rx_done_o	: out	std_logic
      );
  end component;

  signal clk_i: std_logic;
  signal nRST_i: std_logic;
  signal wb_slave_o: wishbone_slave_out;
  signal wb_slave_i: wishbone_slave_in;
  signal TX_RAM_o: wishbone_master_out;
  signal TX_RAM_i: wishbone_master_in;
  signal RX_RAM_o: wishbone_master_out;
  signal RX_RAM_i: wishbone_master_in;
  signal RX_EB_o: wishbone_master_out;
  signal RX_EB_i: wishbone_master_in;
  signal TX_EB_i: wishbone_slave_in;
  signal TX_EB_o: wishbone_slave_out;
  signal IRQ_tx_done_o: std_logic;
  signal IRQ_rx_done_o: std_logic ;

  constant clock_period: time := 10 ns;
  signal stop_the_clock: boolean := false;

begin

  uut: mac_eb_adapter port map ( clk_i         => clk_i,
                                 nRST_i        => nRST_i,
                                 wb_slave_o    => wb_slave_o,
                                 wb_slave_i    => wb_slave_i,
                                 TX_RAM_o      => TX_RAM_o,
                                 TX_RAM_i      => TX_RAM_i,
                                 RX_RAM_o      => RX_RAM_o,
                                 RX_RAM_i      => RX_RAM_i,
                                 RX_EB_o       => RX_EB_o,
                                 RX_EB_i       => RX_EB_i,
                                 TX_EB_i       => TX_EB_i,
                                 TX_EB_o       => TX_EB_o,
                                 IRQ_tx_done_o => IRQ_tx_done_o,
                                 IRQ_rx_done_o => IRQ_rx_done_o );

								 
								 
								 
  stimulus: process
  begin
		
    -- Put initialisation code here
		wait until rising_edge(clk_i);
		nRST_i <= '0';
		
		TX_EB_i <=   (
				CYC => '0',
				STB => '0',
				ADR => (others => '0'),
				SEL => (others => '1'),
				WE  => '1',
				DAT => (others => '0'));
		
		RX_EB_i  <=   (
			ACK   => '0',
			ERR   => '0',
			RTY   => '0',
			STALL => '0',
			DAT   => (others => '0'));
		
		wb_slave_i <=   (
				CYC => '0',
				STB => '0',
				ADR => (others => '0'),
				SEL => (others => '1'),
				WE  => '0',
				DAT => (others => '0'));

		TX_RAM_i  <=   (
			ACK   => '0',
			ERR   => '0',
			RTY   => '0',
			STALL => '0',
			DAT   => (others => '0'));

		RX_RAM_i.ERR  <= '0';
RX_RAM_i.RTY  <= '0';
RX_RAM_i.STALL  <= '0';

	

		wait for clock_period;
		nRST_i <= '1';
			wait for clock_period;
    -- Put test bench stimulus code here

    --stop_the_clock <= true;
    wait;
  end process;

  
  count_io : process(clk_i)
begin
	if rising_edge(clk_i) then
		if (nRST_i = '0') then
		else	
			RX_RAM_i.ACK <=  RX_RAM_o.STB AND RX_RAM_o.CYC;
		end if;
	end if;
end process;
	
  clocking: process
  begin
    while not stop_the_clock loop
      clk_i <= '0', '1' after clock_period / 2;
      wait for clock_period;
	 
    end loop;
    wait;
  end process;

end;