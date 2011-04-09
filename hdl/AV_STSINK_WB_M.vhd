-------------------------------------------------------------------------------
-- White Rabbit Switch / GSI BEL
-------------------------------------------------------------------------------
--
-- unit name: Avalon Master 2 Wishbone Slave Bridge (test stage)
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
-- dependencies: EB_HDR_PKG, piso_sreg_gen
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

-- This implements a bridge between an Avalon Master Device and a Wishbone Slave
--                   
--                Avalon Master  
--                    |
--         |-------|-----|-------|
--         |       | AV S|       |  
--         |       |-----|       |
--         |  AvalonMaster To    |
--         |WishboneSlave Bridge |
--         |       |-----|       |
--         |       | WB M|       |                           
--         |-------|-----|-------|
--                    |
--              WishBone Slave    

---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
use work.wishbone_package.all;

entity AV_STSINK_WB_M is 
port
(
   csi_clk              : in     std_logic;   --! clock input
   csi_n_rst            : in     std_logic;   --! reset input, active low   

   --Wishbone Master IOs
   wb_master_slv_o          : out   std_logic_vector(70 downto 0);	--! Wishbone master output lines
   wb_master_slv_i          : in     std_logic_vector(35 downto 0);    --! 
   
   --Avalon Streaming SINK IOs

	AVS_SL_VALID           	: in    std_logic;
	AVS_SL_STARTOFPACKET     : in    std_logic;
	AVS_SL_ENDOFPACKET        : in    std_logic;
	AVS_SL_DATA      		: in    std_logic_vector(31 downto 0);
	
	AVS_M_READY         	: out     std_logic;
	
	--not used
	--AVS_M_CHANNEL    		: in    std_logic_vector(1 downto 0);
	AVS_SL_ERROR    			: in    std_logic_vector(5 downto 0);
	AVS_SL_EMPTY     		: in    std_logic_vector(1 downto 0)
	
);
end AV_STSINK_WB_M;

architecture behavioral of AV_STSINK_WB_M is


signal SENDING : std_logic;

signal  wb_master_o          : wishbone_master_out;	--! Wishbone master output lines
signal  wb_master_i          : wishbone_master_in;
  
begin

-- necessary to make QUARTUS SOPC builder see the WB intreface as conduit
wb_master_slv_o 	<=	TO_STD_LOGIC_VECTOR(wb_master_o);
wb_master_i			<=	TO_wishbone_master_in(wb_master_slv_i);





wb_master_o.STB		<= AVS_SL_VALID ;
wb_master_o.DAT		<= AVS_SL_DATA;
AVS_M_READY		<= NOT wb_master_i.STALL;
wb_master_o.CYC <= (SENDING OR AVS_SL_STARTOFPACKET);

main: process (csi_clk)
begin
    if rising_edge(csi_clk) then
       --==========================================================================
       -- SYNC RESET                         
       --========================================================================== 
        if (csi_n_rst = '0') then
            wb_master_o.ADR <= (others => '0');
			wb_master_o.SEL <= (others => '1');
			wb_master_o.WE  <= '1';
			SENDING	<= '0';
		else
			if(AVS_SL_STARTOFPACKET = '1') then
				SENDING <= '1';
			end if;
			if(AVS_SL_ENDOFPACKET = '1') then
				SENDING <= '0';
			end if;
		end if;
    end if;                                             
end process;


end behavioral; 
       
    
    
    


