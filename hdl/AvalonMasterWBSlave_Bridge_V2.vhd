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

entity test is 
generic(g_addr_width : natural := 32; g_data_width : natural := 32);
port
(
   csi_clk              : in     std_logic;   --! clock input
   csi_n_rst            : in     std_logic;   --! reset input, active low   

   --Wishbone Master IOs
   wb_master_o          : out    wishbone_master_out;	--! Wishbone master output lines
   wb_master_i          : in     wishbone_master_in;    --! 
   
   --Avalon Slave IOs
   AVS_SL_READ          : in     std_logic;    
   AVS_SL_WRITE         : in     std_logic;    
   AVS_SL_ADDRESS       : in     std_logic_vector(g_addr_width-1 downto 0);    
   AVS_SL_WRITEDATA     : in     std_logic_vector(g_data_width-1 downto 0);    
   AVS_SL_BYTEENABLE    : in     std_logic_vector(g_data_width/8-1 downto 0);        
   AVS_SL_ARBITERLOCK   : in     std_logic;
   
   AVS_SL_WAITREQUEST   : out    std_logic;
   AVS_SL_READDATA      : out    std_logic_vector(g_data_width-1 downto 0);    
   AVS_SL_DATAAVAILABLE : out    std_logic;    
   AVS_SL_READYFORDATA  : out    std_logic;    
   AVS_SL_READDATAVALID : out    std_logic    
      
);
end test;

architecture behavioral of test is
  
begin



p_main: process (csi_clk)
begin
    if rising_edge(csi_clk) then
       --==========================================================================
       -- SYNC RESET                         
       --========================================================================== 
        if (csi_n_rst= '0') then
            wb_master_o <= (CYC => '0',
                            STB => '0',
                            ADR => (others => '0'),
                            SEL => (others => '0'),
                            WE  => '0',
                            DAT => (others => '0'));        
            
            AVS_SL_READDATA         <= (others => '0');    
            AVS_SL_WAITREQUEST      <= '0';
            AVS_SL_DATAAVAILABLE    <= '0';
            AVS_SL_READYFORDATA     <= '0';
            AVS_SL_READDATAVALID    <= '0';    
        else
             --BRIDGE: AVALON MASTER SIDE
            AVS_SL_READDATA         <= wb_master_i.DAT;    
            AVS_SL_DATAAVAILABLE    <= NOT wb_master_i.STALL;
            AVS_SL_READYFORDATA     <= NOT wb_master_i.STALL;
            AVS_SL_WAITREQUEST      <= wb_master_i.STALL; 
            AVS_SL_READDATAVALID    <= wb_master_i.ACK;
                            
            --BRIDGE: WISHBONE SLAVE SIDE
            wb_master_o.STB         <= AVS_SL_READ OR AVS_SL_WRITE;
            wb_master_o.CYC         <= AVS_SL_ARBITERLOCK OR AVS_SL_READ OR AVS_SL_WRITE;
            --wb_master_o.LOCK      <= AVS_SL_ARBITERLOCK;
            wb_master_o.WE          <= AVS_SL_WRITE;
            wb_master_o.ADR         <= AVS_SL_ADDRESS;
            wb_master_o.DAT         <= AVS_SL_WRITEDATA;    
            wb_master_o.SEL         <= AVS_SL_BYTEENABLE;
			
			--Not Connected:
			
			--wb_master_i.ERR
			--wb_master_i.RTY
			--wb_master_o.LOCK      <= AVS_SL_ARBITERLOCK
        end if;
    end if;                                             
end process;


end behavioral; 
       
    
    
    


