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

function IP_HDR_TEMPLATE(SRC_IP : std_logic_vector)
return IPV4_HDR;

function TO_STD_LOGIC_VECTOR(X : UDP_HDR)
return std_logic_vector;

function TO_UDP_HDR(X : std_logic_vector)
return UDP_HDR;

function TO_STD_LOGIC_VECTOR(X : EB_HDR)
return std_logic_vector;

function TO_EB_HDR(X : std_logic_vector)
return EB_HDR;


end EB_HDR_PKG;

package body EB_HDR_PKG is

-- output to std_logic_vector
function TO_STD_LOGIC_VECTOR(X : IPV4_HDR)
return std_logic_vector is
	variable tmp : std_logic_vector(159 downto 0) := (others => '0');
	begin
		tmp :=    X.VER & X.IHL & X.TOS 
		        & X.TOL
				& X.ID
				& X.FLG & X.FRO
				& X.TTL & X.PRO
				& X.SUM
				& X.SRC
				& X.DST;
				
	return tmp;
end function TO_STD_LOGIC_VECTOR;

function TO_STD_LOGIC_VECTOR(X : UDP_HDR)
return std_logic_vector is
	variable tmp : std_logic_vector(63 downto 0) := (others => '0');
	begin
		tmp :=    X.SRC_PORT 
		        & X.DST_PORT
				& X.MLEN
				& X.SUM;
	return tmp;
end function TO_STD_LOGIC_VECTOR;

function TO_STD_LOGIC_VECTOR(X : EB_HDR)
return std_logic_vector is
	variable tmp : std_logic_vector(95 downto 0) := (others => '0');
	begin
		tmp :=    X.EB_MAGIC 
		        & X.VER & X.RESERVED1 & X.ADD_SIZE & X.PORT_SIZE
				& X.ADD_STATUS
				& X.RESERVED2 & X.RD_FIFO & X.RD_CNT
				& X.RESERVED3 & X.WR_FIFO & X.WR_CNT;
	return tmp;
end function TO_STD_LOGIC_VECTOR;


function IP_HDR_TEMPLATE(SRC_IP : std_logic_vector) --loads constants into a given IPV4_HDR record
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
end function IP_HDR_TEMPLATE;
-- cast to records

function TO_IPV4_HDR(X : std_logic_vector)
return IPV4_HDR is
	variable tmp : IPV4_HDR;
	begin
		tmp.VER := X(159 downto 156);	-- 4
		tmp.IHL := X(155 downto 152);	-- 4
		tmp.TOS := X(151 downto 144); 	-- 8
		
		tmp.TOL := X(143 downto 128);	--16
		
		tmp.ID  := X(127 downto 112);	--16
		
		tmp.FLG := X(111 downto 99);	--13
		tmp.FRO := X(98 downto 96);		-- 3
		
		tmp.TTL := X(95 downto 88);		-- 8
		tmp.PRO := X(87 downto 80);		-- 8
		
		tmp.SUM := X(79 downto 64);		--16
		
		tmp.SRC := X(63 downto 32);		--32
		tmp.DST := X(31 downto 0);		--32
				
	return tmp;
end function TO_IPV4_HDR;

function TO_UDP_HDR(X : std_logic_vector)
return UDP_HDR is
	variable tmp : UDP_HDR;
	begin
		tmp.SRC_PORT 	:= X(63 downto 48); --16
		tmp.DST_PORT 	:= X(47 downto 32); --16
		tmp.MLEN		:= X(31 downto 16); --16
		tmp.SUM		:= X(15 downto 0); --16
	return tmp;
end function TO_UDP_HDR;



function TO_EB_HDR(X : std_logic_vector)
return EB_HDR is
	variable tmp : EB_HDR;
	begin
		tmp.EB_MAGIC 	:= X(95 downto 80); --16
		
		tmp.VER 		:= X(79 downto 76);	--  4
		-- reserved 3bit					--  4
		tmp.ADD_SIZE 	:= X(71 downto 68); --  4
		tmp.PORT_SIZE	:= X(67 downto 64); --  4
		tmp.ADD_STATUS	:= X(63 downto 32); -- 32
		
		-- reserved 3bit					-- 3
		tmp.RD_FIFO		:= X(28);			-- 1
		tmp.RD_CNT		:= X(27 downto 16);	--12
		
		-- reserved 3bit				   --  3		
		tmp.RD_FIFO		:= X(12);		   --  1	
		tmp.WR_CNT		:= X(11 downto 0); -- 12
	return tmp;
end function TO_EB_HDR;





----------------------------------------------------------------------------------

end package body;




