---! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
--use work.XXX.all;


package EB_HDR_PKG is

constant c_local_ip			   : std_logic_vector(31 downto 0) := x"C0A80164"; -- fixed address for now. 192.168.1.100 


type IPV4_HDR is record

   -- RX only, use constant fields for TX --------
   VER	   : std_logic_vector(3 downto 0);   
   IHL     : std_logic_vector(3 downto 0); 
   TOS     : std_logic_vector(7 downto 0);
   
   TOL	   : std_logic_vector(15 downto 0); 	
   
   ID      : std_logic_vector(15 downto 0);
   
   FLG     : std_logic_vector(2 downto 0);
   FRO     : std_logic_vector(12 downto 0);
   
   TTL     : std_logic_vector(7 downto 0);
   PRO     : std_logic_vector(7 downto 0);
   -----------------------------------------------
   SUM     : std_logic_vector(15 downto 0);  
   
   SRC	   : std_logic_vector(31 downto 0);
   
   DST	   : std_logic_vector(31 downto 0);

   --- options (optional) here
   
end record;


type UDP_HDR is record
   SRC_PORT,   
   DST_PORT,   
   MLEN,         
   SUM        : std_logic_vector(15 downto 0);
end record;

type EB_HDR is record
	EB_MAGIC	: std_logic_vector(15 downto 0);
	
	VER		 	: std_logic_vector(3 downto 0);
	RESERVED1	: std_logic_vector(3 downto 0);
	ADD_SIZE	: std_logic_vector(3 downto 0);
	PORT_SIZE   : std_logic_vector(3 downto 0);
	
	ADD_STATUS	: std_logic_vector(31 downto 0);
	
	RESERVED2	: std_logic_vector(2 downto 0);
	RD_FIFO		: std_logic;
	RD_CNT		: std_logic_vector(11 downto 0);
	
	RESERVED3	: std_logic_vector(2 downto 0);	
	WR_FIFO		: std_logic;
	WR_CNT		: std_logic_vector(11 downto 0);
end record;
	
function TO_STD_LOGIC_VECTOR(X : IPV4_HDR)
return std_logic_vector;

function TO_IPV4_HDR(X : std_logic_vector)
return IPV4_HDR;

function INIT_IPV4_HDR(SRC_IP : std_logic_vector)
return IPV4_HDR;

function TO_STD_LOGIC_VECTOR(X : UDP_HDR)
return std_logic_vector;

function TO_UDP_HDR(X : std_logic_vector)
return UDP_HDR;

function INIT_UDP_HDR
return UDP_HDR;

function TO_STD_LOGIC_VECTOR(X : EB_HDR)
return std_logic_vector;

function TO_EB_HDR(X : std_logic_vector)
return EB_HDR;

function INIT_EB_HDR
return EB_HDR;

end EB_HDR_PKG;

package body EB_HDR_PKG is

-- output to std_logic_vector
function TO_STD_LOGIC_VECTOR(X : IPV4_HDR)
return std_logic_vector is
	variable tmp : std_logic_vector(159 downto 0) := (others => '0');
	begin
  tmp := X.DST & X.SRC & X.SUM & X.PRO & X.TTL & X.FRO & X.FLG & X.ID & X.TOL & X.TOS & X.IHL & X.VER; 
  return tmp;
end function TO_STD_LOGIC_VECTOR;

function TO_STD_LOGIC_VECTOR(X : UDP_HDR)
return std_logic_vector is
	variable tmp : std_logic_vector(63 downto 0) := (others => '0');
	begin
		tmp :=  X.SUM & X.MLEN & X.DST_PORT & X.SRC_PORT;
	return tmp;
end function TO_STD_LOGIC_VECTOR;

function TO_STD_LOGIC_VECTOR(X : EB_HDR)
return std_logic_vector is
	variable tmp : std_logic_vector(95 downto 0) := (others => '0');
	begin
	  		tmp := X.WR_CNT & X.WR_FIFO & X.RESERVED3 & X.RD_CNT & X.RD_FIFO & X.RESERVED2 
	  		     & X.ADD_STATUS & X.PORT_SIZE & X.ADD_SIZE & X.RESERVED1 & X.VER & X.EB_MAGIC;

	return tmp;
end function TO_STD_LOGIC_VECTOR;


function INIT_IPV4_HDR(SRC_IP : std_logic_vector) --loads constants into a given IPV4_HDR record
return IPV4_HDR is
variable tmp : IPV4_HDR;


	begin
		tmp.VER := 	x"4"; -- 4
		tmp.IHL := 	x"5"; -- 4
		tmp.TOS :=  x"00";	-- 8
		
		tmp.TOL := (others => '0');
					 
		tmp.ID  := 	(others => '0');--16
		
		tmp.FLG := 	"010";--
		tmp.FRO := 	(others => '0');-- 0
		
		tmp.TTL := 	x"40";	-- 64 Hops
		tmp.PRO := 	x"11";	-- UDP
		
		tmp.SUM := (others => '0');		--16
		
		tmp.SRC := SRC_IP;		--32 -- SRC is already known
		tmp.DST := (others => '0');		--32
		
	return tmp;
end function INIT_IPV4_HDR;









-- cast to records

function TO_IPV4_HDR(X : std_logic_vector)
return IPV4_HDR is
	variable tmp : IPV4_HDR;
	begin
		tmp.VER := X(3 downto 0);	-- 4
		tmp.IHL := X(7 downto 4);	-- 4
		tmp.TOS := X(15 downto 8); 	-- 8
		
		tmp.TOL := X(31 downto 16);	--16
		
		tmp.ID  := X(47 downto 32);	--16
		
		tmp.FLG := X(60 downto 48);	--13
		tmp.FRO := X(63 downto 61);		-- 3
		
		tmp.TTL := X(71 downto 64);		-- 8
		tmp.PRO := X(79 downto 72);		-- 8
		
		tmp.SUM := X(95 downto 80);		--16
		
		tmp.SRC := X(127 downto 96);		--32
		tmp.DST := X(159 downto 128);		--32
		
  return tmp;
end function TO_IPV4_HDR;

function TO_UDP_HDR(X : std_logic_vector)
return UDP_HDR is
	variable tmp : UDP_HDR;
	begin
		tmp.SRC_PORT 	:= X(15 downto 0); --16
		tmp.DST_PORT 	:= X(31 downto 16); --16
		tmp.MLEN		:= X(47 downto 32); --16
		tmp.SUM			:= X(63 downto 48); --16
	return tmp;
end function TO_UDP_HDR;

function INIT_UDP_HDR
return UDP_HDR is
	variable tmp : UDP_HDR;
	begin
		tmp.SRC_PORT 	:= (others => 'Z'); --16
		tmp.DST_PORT 	:= (others => '1'); --16
		tmp.MLEN		:= (others => '0'); --16
		tmp.SUM			:= (others => '0'); --16
	return tmp;
end function INIT_UDP_HDR;


function TO_EB_HDR(X : std_logic_vector)
return EB_HDR is
	variable tmp : EB_HDR;
	begin
		tmp.EB_MAGIC 	:= X(15 downto 0); --16
		
		tmp.VER 		:= X(19 downto 16);	--  4
		tmp.RESERVED1 	:= X(23 downto 20);-- reserved 3bit				
		tmp.ADD_SIZE 	:= X(27 downto 24); --  4
		tmp.PORT_SIZE	:= X(31 downto 28); --  4
		tmp.ADD_STATUS	:= X(63 downto 32); -- 32
		
		tmp.RESERVED2 	:= X(66 downto 64);-- reserved 3bit					
		tmp.RD_FIFO		:= X(67);			-- 1
		tmp.RD_CNT		:= X(79 downto 68);	--12
		
		tmp.RESERVED3 	:= X(82 downto 80);-- reserved 3bit				   --  3		
		tmp.WR_FIFO		:= X(83);		   --  1	
		tmp.WR_CNT		:= X(95 downto 84); -- 12
	return tmp;
end function TO_EB_HDR;

function INIT_EB_HDR
return EB_HDR is
	variable tmp : EB_HDR;
	begin
		tmp.EB_MAGIC 	:= (others => 'Z'); --16
		
		tmp.VER 		:= (others => '1');	--  4
		tmp.RESERVED1 	:= (others => '0');-- reserved 3bit				
		tmp.ADD_SIZE 	:= (others => '0'); --  4
		tmp.PORT_SIZE	:= (others => '0'); --  4
		tmp.ADD_STATUS	:= (others => '0'); -- 32
		
		tmp.RESERVED2 := (others => '0');-- reserved 3bit					
		tmp.RD_FIFO		:= '0';			-- 1
		tmp.RD_CNT		:= (others => '0');	--12
		
		tmp.RESERVED3 := (others => '0');-- reserved 3bit				   --  3		
		tmp.WR_FIFO		:= '0';		   --  1	
		tmp.WR_CNT		:= (others => '0'); -- 12
	return tmp;
end function INIT_EB_HDR;



----------------------------------------------------------------------------------

end package body;




