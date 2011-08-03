library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package vhdl_2008_workaround_pkg is

function sign(X: integer)
return integer;
 
function minimum(A : integer; B : integer)
return integer;

function maximum(A : integer; B : integer)
return integer;

function ld(X : natural)
return natural;

end vhdl_2008_workaround_pkg;

 package body vhdl_2008_workaround_pkg is
 
function minimum(A : integer; B : integer)
return integer is
    variable tmp : integer;
    begin
 		if(A < B) then
			tmp := A;
		else
			tmp := B;
		end if;
  return tmp;
end function minimum;

function maximum(A : integer; B : integer)
return integer is
    variable tmp : integer;
    begin
		if(A > B) then
			tmp := A;
		else
			tmp := B;
		end if;
			
  return tmp;
end function  maximum;  

function sign(X : integer)
return integer is
    variable tmp : natural := 0;
	begin
		if(X = 0) then
			tmp := 0;
		elsif(X > 0)
			tmp := 1;
		else
			tmp := -1;
		end if;	
	return tmp;
end function sign;  
g

function ld(X : natural)
return natural is
    variable tmp : natural := 0;
	variable X_bin : unsigned(31 downto 0) := to_unsigned(X, 32);
	variable Y_bin : unsigned(31 downto 0) := (others => '0');
	begin
			X_bin := NOT(X_bin);
			Y_bin := (X_bin + 1) XOR X_bin;
			tmp := to_integer(Y_bin);
	return tmp;
end function ld;  
  

end package body;