-------------------------------------------------------------------------------
-- White Rabbit Switch / GSI BEL
-------------------------------------------------------------------------------
--
-- unit name: Parallel-In/Serial-Out shift register
--
-- author: Mathias Kreider, m.kreider@gsi.de
--
-- date: $Date:: $:
--
-- version: $Rev:: $:
--
-- description: <file content, behaviour, purpose, special usage notes...>
-- <further description>
--
-- dependencies: <entity name>, ...
--
-- references: <reference one>
-- <reference two> ...
--
-- modified by: $Author:: $:
--
-------------------------------------------------------------------------------
-- last changes: <date> <initials> <log>
-- <extended description>
-------------------------------------------------------------------------------
-- TODO: <next thing to do>
-- <another thing to do>
--
-- This code is subject to GPL
-------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.wishbone_package.all;

entity mac_eb_adapter is 
 port(
		clk_i    	: in    std_logic;                                        --clock
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

end mac_eb_adapter;


architecture behavioral of mac_eb_adapter is

-- wishbone IF
signal 		ctrl	  		: std_logic_vector(31 downto 0);	--x00
alias		buffers_rdy		: std_logic is ctrl(0);

signal 		base_adr_rx		: std_logic_vector(31 downto 0);	--x04
signal 		base_adr_tx		: std_logic_vector(31 downto 0);	--x08
signal 		length_rx		: std_logic_vector(31 downto 0);        --C
signal 		bytes_rx		: std_logic_vector(31 downto 0);        --C
signal 		bytes_tx		: std_logic_vector(31 downto 0);        --C
signal		rx_done			: std_logic;

signal 		EB_STALL : std_logic;

signal wb_adr : std_logic_vector(31 downto 0);
alias adr :  std_logic_vector(7 downto 0) is wb_adr(7 downto 0);

--DMA controller
signal IRQ_tx_done : std_logic;
signal IRQ_rx_done : std_logic;

type FSM is (IDLE, INIT, TRANSFER, WAITING, DONE) ;

signal state_tx : FSM;
signal state_rx : FSM;
signal rx_counter : unsigned(15 downto 0);
signal tx_counter : unsigned(31 downto 0);

signal RX_RAM_DAT_REG : std_logic_vector(31 downto 0);



begin



wb_adr <= wb_slave_i.ADR;

	
wishbone_if	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then

			ctrl 		<= (others => '0');
			base_adr_tx <= (others => '0');
			base_adr_rx <= (others => '0');
			length_rx	<= (others => '0');
			--length_tx	<= (others => '0');
			
			wb_slave_o	<=   (
												ACK   => '0',
												ERR   => '0',
												RTY   => '0',
												STALL => '0',
												DAT   => (others => '0'));
		else
            wb_slave_o.ACK <= wb_slave_i.CYC AND wb_slave_i.STB;
			wb_slave_o.DAT  <= (others => '0');
			ctrl			<= (others => '0');
			
			if(wb_slave_i.WE ='1') then
				case adr  is				
					when x"00" =>	ctrl		<= wb_slave_i.DAT AND x"00000001";
					when x"04" =>	base_adr_tx	<= wb_slave_i.DAT;
					when x"08" =>	base_adr_rx	<= wb_slave_i.DAT;
					when x"0C" =>	length_rx	<= wb_slave_i.DAT;
					when others => null;
				end case;		
			else
				 -- set output to zero so all bits are driven
				case adr  is
					--when x"00" =>	ctrl		<= wb_slave_i.DAT AND x"00000003";
					when x"04" =>	wb_slave_o.DAT <= base_adr_tx;
					when x"08" =>	wb_slave_o.DAT <= base_adr_rx;
					when x"0C" =>	wb_slave_o.DAT <= length_rx;
					when x"10" =>	wb_slave_o.DAT <= bytes_rx;
					when x"14" =>	wb_slave_o.DAT <= bytes_tx;
					when others => null;
				end case;
			end if;	

        end if;    
    end if;
end process;

------------------------------------------
TX_EB_o.STALL 	<= TX_RAM_i.STALL;
TX_EB_o.ACK 	<= TX_RAM_i.ACK;


TX_RAM_o.CYC	<= TX_EB_i.CYC;
TX_RAM_o.STB	<= TX_EB_i.STB;
TX_RAM_o.DAT	<= TX_EB_i.DAT;	
TX_RAM_o.ADR	<= std_logic_vector(tx_counter);
TX_RAM_o.WE		<= '1';
TX_RAM_o.SEL	<= (others => '1');

IRQ_tx_done_o	<= IRQ_tx_done;

bytes_tx <= std_logic_vector(tx_counter);


dma_tx	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then

			TX_EB_o.ERR 	<= '0';
			TX_EB_o.RTY 	<= '0';
			TX_EB_o.DAT 	<= (others => '0');
			RX_RAM_DAT_REG  <= (others => '0');
			
			IRQ_tx_done	<= '0';
			tx_counter <= (others => '0');
			state_tx <= IDLE;
		else
           		
			case state_tx  is				
					when IDLE 		=>	if(buffers_rdy = '1') then -- rx is already receiving and the EBCore wants to send an answer
											state_tx <= INIT;	
										end if;
					
					when INIT 		=>	IRQ_tx_done <= '0';
										tx_counter <= unsigned(base_adr_tx); -- reply must be the same length than request
										state_tx <= TRANSFER;
																			
					when TRANSFER 	=>	if((tx_counter < unsigned(length_rx)+unsigned(base_adr_tx)) AND TX_EB_i.CYC = '1') then
											
											if(TX_EB_i.STB = '1' AND TX_RAM_i.STALL = '0') then
												tx_counter <= tx_counter +4;
											end if;		
										
										else
											state_tx <= DONE;
										end if;
										
					when DONE		=>	IRQ_tx_done <= '1';
										state_tx <= IDLE;
	
					when others 	=> 	state_tx <= IDLE;
			end case;	
		
		end if;    
    end if;
end process;

IRQ_rx_done_o	<= IRQ_rx_done;

rx_done <= 		'0' when (rx_counter < (unsigned(length_rx(15 downto 0))+unsigned(base_adr_rx(15 downto 0))))
		else 	'1';

RX_RAM_o.STB <= NOT (RX_EB_i.STALL) AND NOT rx_done;
RX_RAM_o.ADR <= std_logic_vector(resize(rx_counter, 32));
RX_EB_o.DAT	<= RX_RAM_i.DAT;
RX_EB_o.STB	<= RX_RAM_i.ACk;
bytes_rx <= std_logic_vector(resize(rx_counter, 32));

dma_rx	:	process (clk_i)
  begin
      if (clk_i'event and clk_i = '1') then
        if(nRSt_i = '0') then

			state_rx <= IDLE;
			IRQ_rx_done	<= '0';
			rx_counter <= (others => '0');
			
			RX_RAM_o.CYC	<= '0';
			RX_RAM_o.WE		<= '0';
			RX_RAM_o.SEL	<= (others => '1');
			RX_RAM_o.DAT	<= (others => '0');
			
			RX_EB_o.CYC	<= '0';
			
			RX_EB_o.WE		<= '1';
			RX_EB_o.SEL	<= (others => '1');
			RX_EB_o.ADR	<= (others => '0');
			EB_STALL <= '0';
			
		else
           	EB_STALL <= RX_EB_i.STALL;	
			case state_rx  is				
					when IDLE 		=>	if(buffers_rdy ='1') then
											state_rx <= INIT;	
										end if;
					
					when INIT 		=>	IRQ_rx_done <= '0';
										rx_counter 	<= unsigned(base_adr_rx(15 downto 0));
										RX_RAM_o.CYC	<= '1';
										RX_EB_o.CYC <= '1';
										state_rx 	<= TRANSFER;
																			
					when TRANSFER 	=>	if (rx_done = '0') then --- all rx done
											if(RX_RAM_i.STALL = '0' and RX_EB_i.STALL = '0' AND EB_STALL = '0') then
												rx_counter <= rx_counter +4;
											end if;	
										else
											state_rx <= DONE;
										    RX_RAM_o.CYC <= '0';
										end if;
										
					when DONE		=>	RX_EB_o.CYC <= '0';
										IRQ_rx_done <= '1';
										state_rx <= IDLE;
	
					when others 	=> state_rx <= IDLE;
			end case;	
		
		end if;    
    end if;
end process;
  
end behavioral;