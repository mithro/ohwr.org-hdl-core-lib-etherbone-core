library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.wishbone_pkg.all;

entity wb_ram is 
 port(
		clk_i    		     : in std_logic;                                        --clock
    nRST_i       		 : in std_logic;

		wb_slave_o      : out t_wishbone_slave_out;	--! EB Wishbone slave lines
		wb_slave_i      : in  t_wishbone_slave_in
    );

end entity wb_ram;    

architecture behavioral of wb_ram is

constant c_ram_size_bytes : natural := 2048;

subtype t_mem8 IS std_logic_vector(7 DOWNTO 0);	
TYPE t_memblock IS ARRAY(0 to c_ram_size_bytes/4-1) OF t_mem8;

signal ram_block0 : t_memblock;
signal ram_block1 : t_memblock;
signal ram_block2 : t_memblock;
signal ram_block3 : t_memblock;

signal address: integer RANGE 0 to c_ram_size_bytes/4-1;
signal address_check : unsigned(20 downto 0);
signal q: std_logic_vector (31 DOWNTO 0);

signal address_reg : integer RANGE 0 to c_ram_size_bytes/4-1;
signal address_check_reg : unsigned(20 downto 0);

signal ack_reg : std_logic;
signal sel_reg : std_logic_vector(3 downto 0);
signal data_reg: std_logic_vector (31 DOWNTO 0);
signal wr : std_logic;
signal rd : std_logic;


begin

address <= to_integer(unsigned(wb_slave_i.adr(10 downto 2)));
address_check <= unsigned(wb_slave_i.adr(31 downto 11));
wb_slave_o.rty <= '0';
wb_slave_o.stall <= '0';
wb_slave_o.int <= '0';
wb_slave_o.dat <= q;

   


   PROCESS (clk_i)
   BEGIN
      IF (clk_i'event AND clk_i = '1') THEN
        
        ack_reg <= wb_slave_i.cyc and wb_slave_i.stb;
        
        if(address_check_reg = 0) then
          wb_slave_o.ack <=  ack_reg;
          wb_slave_o.err <=  '0';
        else
          wb_slave_o.ack <=  '0';
          wb_slave_o.err <=  '1';
        end if;
        
        wr <=  wb_slave_i.cyc and wb_slave_i.stb and wb_slave_i.we;
        rd <=  wb_slave_i.cyc and wb_slave_i.stb and not wb_slave_i.we;
        address_reg <= address;
        address_check_reg <= address_check;
        data_reg <= wb_slave_i.dat;
        sel_reg <= wb_slave_i.sel;
       
       if(wr = '1') then
				if(sel_reg(3) = '1') then 
					ram_block3(address_reg) <= data_reg(31 downto 24);
				end if;
				if(sel_reg(2) = '1') then 
					ram_block2(address_reg) <= data_reg(23 downto 16);
				end if;
				if(sel_reg(1) = '1') then 
					ram_block1(address_reg) <= data_reg(15 downto 8);
				end if;
				if(sel_reg(0) = '1') then 
					ram_block0(address_reg) <= data_reg(7 downto 0);
				end if;
				end if;
				
				if(rd = '1') then
          q <= ram_block3(address_reg)& ram_block2(address_reg) & ram_block1(address_reg) & ram_block0(address_reg); 
        end if;
      END IF;
   END PROCESS;
   
   

END behavioral;