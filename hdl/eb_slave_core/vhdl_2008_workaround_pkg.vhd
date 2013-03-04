--! @file vhdl_2008_workaround_pkg.vhd
--! @brief VHDL 2008 alike functions
--!
--! Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--! @bug No know bugs.
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package vhdl_2008_workaround_pkg is


 
function minimum(A : integer; B : integer)
return integer;

function maximum(A : integer; B : integer)
return integer;

function ld(X : natural)
return natural;

function sign(X : integer)
return integer;

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

function ld(X : natural)
return natural is
    variable tmp : natural := 32;
	variable search : std_logic_vector(31 downto 0) := (others => '0');
    variable found : std_logic := '0';
	begin
		search := std_logic_vector(to_unsigned(X, 32));
		if(X = 0) then
		  tmp := 1;
		else  
		  while(tmp > 0 AND found = '0') loop
			 if(found = '0') then 
			   tmp := tmp -1;
			 end if;
			 found := search(tmp);
			 
		  end loop;			
    end if;
	return tmp;
end function ld;  

function sign(X : integer)
return integer is
    variable tmp : integer := 0;
	begin
		if(X = 0) then
			tmp := 0;
		elsif(X > 0) then
			tmp := 1;
		else
			tmp := -1;
		end if;	
	return tmp;
end function sign;    



end package body;
