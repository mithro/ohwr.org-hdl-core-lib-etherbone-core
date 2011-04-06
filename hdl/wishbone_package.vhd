library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package wishbone_package is

   constant wishbone_address_width	: integer := 32;
   constant wishbone_data_width		: integer := 32;
   
   subtype wishbone_address is 
      std_logic_vector(wishbone_address_width-1 downto 0);
   subtype wishbone_data is
      std_logic_vector(wishbone_data_width-1 downto 0);
   subtype wishbone_byte_select is
      std_logic_vector((wishbone_address_width/8)-1 downto 0);
   subtype wishbone_cycle_type is
      std_logic_vector(2 downto 0);
   subtype wishbone_burst_type is
      std_logic_vector(1 downto 0);

   -- A B.4 Wishbone pipelined master
   -- Pipelined wishbone is always LOCKed during CYC (else ACKs would get lost)
   type wishbone_master_out is record
      CYC	: std_logic;
      STB	: std_logic;
      ADR	: wishbone_address;
      SEL	: wishbone_byte_select;
      WE	: std_logic;
      DAT	: wishbone_data;
   end record wishbone_master_out;
   subtype wishbone_slave_in is wishbone_master_out;
   
   type wishbone_slave_out is record
      ACK	: std_logic;
      ERR	: std_logic;
      RTY	: std_logic;
      STALL	: std_logic;
      DAT	: wishbone_data;
   end record wishbone_slave_out;
   subtype wishbone_master_in is wishbone_slave_out;

   type wishbone_v3_master_out is record
      CYC	: std_logic;
      STB	: std_logic;
      ADR	: wishbone_address;
      SEL	: wishbone_byte_select;
      WE	: std_logic;
      LOCK	: std_logic;
      DAT	: wishbone_data;
      CTI	: wishbone_cycle_type;
      BTE	: wishbone_burst_type;
   end record wishbone_v3_master_out;
   subtype wishbone_v3_slave_in is wishbone_v3_master_out;
   
   type wishbone_v3_slave_out is record
      ACK	: std_logic;
      ERR	: std_logic;
      RTY	: std_logic;
      DAT	: wishbone_data;
   end record wishbone_v3_slave_out;
   subtype wishbone_v3_master_in is wishbone_v3_slave_out;

   type wishbone_master_out_vector is array (natural range <>) of wishbone_master_out;
   type wishbone_slave_out_vector  is array (natural range <>) of wishbone_slave_out;
   subtype wishbone_slave_in_vector  is wishbone_master_out_vector;
   subtype wishbone_master_in_vector is wishbone_slave_out_vector;
   
   type wishbone_v3_master_out_vector is array (natural range <>) of wishbone_v3_master_out;
   type wishbone_v3_slave_out_vector  is array (natural range <>) of wishbone_v3_slave_out;
   subtype wishbone_v3_slave_in_vector  is wishbone_v3_master_out_vector;
   subtype wishbone_v3_master_in_vector is wishbone_v3_slave_out_vector;
   
   type wishbone_address_vector   is array (natural range <>) of wishbone_address;
   type wishbone_data_vector      is array (natural range <>) of wishbone_data;
end wishbone_package;