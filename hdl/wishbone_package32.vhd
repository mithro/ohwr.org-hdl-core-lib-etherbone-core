library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package wb32_package is

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
   type wb32_master_out is record
      CYC	: std_logic;
      STB	: std_logic;
      ADR	: wishbone_address;
      SEL	: wishbone_byte_select;
      WE	: std_logic;
      DAT	: wishbone_data;
   end record wb32_master_out;
   subtype wb32_slave_in is wb32_master_out;
   
   type wb32_slave_out is record
      ACK	: std_logic;
      ERR	: std_logic;
      RTY	: std_logic;
      STALL	: std_logic;
      DAT	: wishbone_data;
   end record wb32_slave_out;
   subtype wb32_master_in is wb32_slave_out;

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

   type wb32_master_out_vector is array (natural range <>) of wb32_master_out;
   type wb32_slave_out_vector  is array (natural range <>) of wb32_slave_out;
   subtype wb32_slave_in_vector  is wb32_master_out_vector;
   subtype wb32_master_in_vector is wb32_slave_out_vector;
   
   type wishbone_v3_master_out_vector is array (natural range <>) of wishbone_v3_master_out;
   type wishbone_v3_slave_out_vector  is array (natural range <>) of wishbone_v3_slave_out;
   subtype wishbone_v3_slave_in_vector  is wishbone_v3_master_out_vector;
   subtype wishbone_v3_master_in_vector is wishbone_v3_slave_out_vector;
   
   type wishbone_address_vector   is array (natural range <>) of wishbone_address;
   type wishbone_data_vector      is array (natural range <>) of wishbone_data;

    function TO_STD_LOGIC_VECTOR(X : wb32_slave_out)
return std_logic_vector;

function TO_wb32_slave_out(X : std_logic_vector)
return wb32_slave_out;

 function TO_STD_LOGIC_VECTOR(X : wb32_master_out)
return std_logic_vector;

function TO_wb32_master_out(X : std_logic_vector)
return wb32_master_out;



 -- function TO_STD_LOGIC_VECTOR(X : wb32_master_in)
-- return std_logic_vector;

function TO_wb32_master_in(X : std_logic_vector)
return wb32_master_in;

 -- function TO_STD_LOGIC_VECTOR(X : wb32_slave_in)
-- return std_logic_vector;

function TO_wb32_slave_in(X : std_logic_vector)
return wb32_slave_in;
   
   end wb32_package;

 package body wb32_package is
 
 function TO_STD_LOGIC_VECTOR(X : wb32_slave_out)
return std_logic_vector is
    variable tmp : std_logic_vector(35 downto 0) := (others => '0');
    begin
  tmp := X.ACK & X.ERR & X.RTY & X.STALL & X.DAT; 
  return tmp;
end function TO_STD_LOGIC_VECTOR;  

function TO_wb32_slave_out(X : std_logic_vector)
return wb32_slave_out is
    variable tmp : wb32_slave_out;
    begin
        tmp.ACK 	:= X(35);
		tmp.ERR 	:= X(34);
		tmp.RTY 	:= X(33);
		tmp.STALL 	:= X(32);
		tmp.DAT 	:= X(31 downto 0);

    return tmp;
end function TO_wb32_slave_out;
 
   
 function TO_STD_LOGIC_VECTOR(X : wb32_master_out)
return std_logic_vector is
    variable tmp : std_logic_vector(70 downto 0) := (others => '0');
    begin
  tmp := X.CYC & X.STB & X.ADR & X.SEL & X.WE & X.DAT; 
  return tmp;
end function TO_STD_LOGIC_VECTOR;  

function TO_wb32_master_out(X : std_logic_vector)
return wb32_master_out is
    variable tmp : wb32_master_out;
    begin
        tmp.CYC := X(70);
		tmp.STB := X(69);
		tmp.ADR := X(68 downto 37);
		tmp.SEL := X(36 downto 33);
		tmp.WE 	:= X(32);
		tmp.DAT := X(31 downto 0);
    return tmp;
end function TO_wb32_master_out;

 -- function TO_STD_LOGIC_VECTOR(X : wb32_master_in)
-- return std_logic_vector is
    -- variable tmp : std_logic_vector(35 downto 0) := (others => '0');
    -- begin
  -- tmp := X.ACK & X.ERR & X.RTY & X.STALL & X.DAT; 
  -- return tmp;
-- end function TO_STD_LOGIC_VECTOR;  

function TO_wb32_master_in(X : std_logic_vector)
return wb32_master_in is
    variable tmp : wb32_master_in;
    begin
        tmp.ACK 	:= X(35);
		tmp.ERR 	:= X(34);
		tmp.RTY 	:= X(33);
		tmp.STALL 	:= X(32);
		tmp.DAT 	:= X(31 downto 0);

    return tmp;
end function TO_wb32_master_in;
 
   
 -- function TO_STD_LOGIC_VECTOR(X : wb32_slave_in)
-- return std_logic_vector is
    -- variable tmp : std_logic_vector(70 downto 0) := (others => '0');
    -- begin
  -- tmp := X.CYC & X.STB & X.ADR & X.SEL & X.WE & X.DAT; 
  -- return tmp;
-- end function TO_STD_LOGIC_VECTOR;  

function TO_wb32_slave_in(X : std_logic_vector)
return wb32_slave_in is
    variable tmp : wb32_slave_in;
    begin
        tmp.CYC := X(70);
		tmp.STB := X(69);
		tmp.ADR := X(68 downto 37);
		tmp.SEL := X(36 downto 33);
		tmp.WE 	:= X(32);
		tmp.DAT := X(31 downto 0);
    return tmp;
end function TO_wb32_slave_in;

end package body;