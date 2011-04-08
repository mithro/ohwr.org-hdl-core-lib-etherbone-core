-------------------------------------------------------------------------------
-- White Rabbit Switch / GSI BEL
-------------------------------------------------------------------------------


---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
use work.wishbone_package.all;

entity AV_STSRC_WB_SLV is 
generic(g_data_width : natural := 32);
port
(
   csi_clk              : in     std_logic;   --! clock input
   csi_n_rst            : in     std_logic;   --! reset input, active low   

   --Wishbone Master IOs
   --wb_slave_slv_o          : out    wishbone_slave_out;	--! Wishbone master output lines
   --wb_slave_i          : in     wishbone_slave_in;    --! 
   
	wb_slave_slv_o          : out    std_logic_vector(35 downto 0);	--! Wishbone master output lines
    wb_slave_slv_i          : in     std_logic_vector(70 downto 0);
   --Avalon Streaming SRC IOs

	AVS_M_VALID          	: out    std_logic;
	AVS_M_STARTOFPACKET     : out    std_logic;
	AVS_M_ENDOFPACKET        : out    std_logic;
	AVS_M_DATA      		: out    std_logic_vector(31 downto 0);
	

	AVS_M_ERROR    			: out    std_logic;
	AVS_M_EMPTY     		: out    std_logic_vector(1 downto 0);
	
	AVS_SL_READY         	: in     std_logic
      
);
end AV_STSRC_WB_SLV;

architecture behavioral of AV_STSRC_WB_SLV is


signal CYC : std_logic;
signal wb_slave_o : wishbone_slave_out;
signal wb_slave_i : wishbone_slave_in;
  
begin

-- necessary to make QUARTUS SOPC builder see the WB intreface as conduit
wb_slave_slv_o 	<=	TO_STD_LOGIC_VECTOR(wb_slave_o);
wb_slave_i		<=	TO_wishbone_slave_in(wb_slave_slv_i);


AVS_M_STARTOFPACKET <= wb_slave_i.CYC AND NOT CYC;
AVS_M_ENDOFPACKET 	<= NOT wb_slave_i.CYC AND CYC;
AVS_M_VALID 		<= wb_slave_i.STB;
AVS_M_DATA 			<= wb_slave_i.DAT;
wb_slave_o.STALL 	<= NOT AVS_SL_READY;


p_main: process (csi_clk)
begin
    if rising_edge(csi_clk) then
       --==========================================================================
       -- SYNC RESET                         
       --========================================================================== 
        	
		if (csi_n_rst= '0') then
            wb_slave_o.ACK   <= '0';
			wb_slave_o.ERR    <= '0';
			wb_slave_o.RTY    <= '0';
			wb_slave_o.DAT    <= (others => '0');
								
            --not used
			AVS_M_ERROR    			<= '0';
			AVS_M_EMPTY     		<= (others => '0');
			CYC <= '0';

        else
			CYC <= wb_slave_i.CYC;
			wb_slave_o.ACK <= wb_slave_i.STB AND AVS_SL_READY;
		
		end if;
    end if;                                             
end process;


end behavioral; 
       
    
    
    


