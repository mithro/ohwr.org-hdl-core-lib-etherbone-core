--! Standard library
library IEEE;
--! Standard packages    
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

--! Additional library
library work;
--! Additional packages    
--use work.XXX.all;


package EB_HDR_PKG is

-- tx only
constant cIP_ver_hlen_difserv : std_logic_vector(15 downto 0) := "0100010100000000";
constant cIP_id               : std_logic_vector(15 downto 0) := "0000000000000000";
constant cIP_flags_fragOffset : std_logic_vector(15 downto 0) := "0100000000000000";
constant cIP_ttl_proto        : std_logic_vector(15 downto 0) := "0100000000010001";
constant cIP_opt              : std_logic_vector(23 downto 0) := x"DEADBE";


type IPV4_HDR is record

   -- RX only, use constant fields for TX --------
   VER,    
   IHL     : std_logic_vector(3 downto 0);
   TOS     : std_logic_vector(7 downto 0);
   ID      : std_logic_vector(15 downto 0);
   FLG     : std_logic_vector(2 downto 0);
   FRO     : std_logic_vector(12 downto 0);
   TTL     : std_logic_vector(7 downto 0);
   PRO     : std_logic_vector(7 downto 0);
   -----------------------------------------------
   
   TOL,
   SUM      :         unsigned(15 downto 0);  
   SRC,     
   DEST     : std_logic_vector(31 downto 0);
   OPT      : std_logic_vector(23 downto 0); 
end record;


type UDP_HDR is record
   SRC_PORT,   
   DEST_PORT   : std_logic_vector(15 downto 0);
   MLEN,         
   SUM         :         unsigned(15 downto 0);
end record;

type EB_HDR is record
   -- not actual sequence, changed for coding style.
   -- see EB_PACK_HDR_TO_SLV16 output function for order
   
   ACKF,
   SWABF :                    std_logic;
     
   RPORT ,  
   PRO :   std_logic_vector(7 downto 0);
   
   SAD,     
   ADINC, 
   RCNT,  
   RREM,
   SEQN : unsigned(7 downto 0);
   
end record;

type EB_PACK_HDR is record
   IPV4 : IPV4_HDR;
   UDP  : UDP_HDR;
   EB   : EB_HDR;
end record;



function EB_PACK_HDR_TO_SLV16(index : natural; X : EB_PACK_HDR) return std_logic_vector;

function SLV16_TO_EB_PACK_HDR(index : natural; X : std_logic_vector; HDR : EB_PACK_HDR) return EB_PACK_HDR;

end EB_HDR_PKG;

package body EB_HDR_PKG is

  -- send out the complete header in 16bit words. 
  -- TX function, uses constant fields.
function EB_PACK_HDR_TO_SLV16(index :  natural; X : EB_PACK_HDR)
              return std_logic_vector is
variable tmp: std_logic_vector(15 downto 0) := (others => '0');
begin
  case index is
    -- IPV4 Hdr
    when 23       => tmp := cIP_ver_hlen_difserv;       
    when 22       => tmp := std_logic_vector(X.IPV4.TOL);        
    when 21       => tmp := cIP_id; -- ID
    when 20       => tmp := cIP_flags_fragOffset; 
    when 19       => tmp := cIP_ttl_proto;   
    when 18       => tmp := std_logic_vector(X.IPV4.SUM); 
    when 17       => tmp := X.IPV4.SRC( 31 downto 16); 
    when 16       => tmp := X.IPV4.SRC( 15 downto 0); 
    when 15       => tmp := X.IPV4.DEST(31 downto 16); 
    when 14       => tmp := X.IPV4.DEST(15 downto 0);
    when 13       => tmp := cIP_opt(23 downto 8); 
    when 12       => tmp := cIP_opt(7 downto 0) & "00000000";
    -- UDP Hdr
    when 11       => tmp := X.UDP.SRC_PORT;
    when 10       => tmp := X.UDP.DEST_PORT;
    when 9       => tmp := std_logic_vector(X.UDP.MLEN);
    when 8       => tmp := std_logic_vector(X.UDP.SUM);
    -- EB Hdr
    when 7       => tmp := X.EB.PRO & std_logic_vector(X.EB.SAD) ;  
    when 6       => tmp := std_logic_vector(X.EB.ADINC) & std_logic_vector(X.EB.RCNT); 
    when 5       => tmp := "0000000" & X.EB.ACKF & "0000000" & X.EB.SWABF; 
    when 4       => tmp := X.EB.RPORT & std_logic_vector(X.EB.RREM); 
    when 3       => tmp := std_logic_vector(X.EB.SEQN) & "00000000"; 
    when 0 to 2 => tmp := "0000000000000000";
    
    when others   => tmp := x"DEAD";
  end case;
  return tmp;             
end EB_PACK_HDR_TO_SLV16;

  -- convert 16b words to EB_PACK_HDR. use 'RX only' fields
function SLV16_TO_EB_PACK_HDR(index : natural; X : std_logic_vector; HDR : EB_PACK_HDR)
              return EB_PACK_HDR is
variable tmp : EB_PACK_HDR := HDR;

begin
  case index is
    -- IPV4 HDR
    when  20       =>  tmp.IPV4.VER  := X(15 downto 12); 
                      tmp.IPV4.IHL  := X(11 downto 8);
                      tmp.IPV4.TOS  := X(7 downto 0);
    when 19      =>  tmp.IPV4.TOL  := unsigned(X);                  
    when 18      =>  tmp.IPV4.ID   := X;
    
    when 17       =>  tmp.IPV4.FLG  := X(15 downto 13);
                      tmp.IPV4.FRO  := X(12 downto 0);
    
    when 16       =>  tmp.IPV4.TTL  := X(15 downto 8);
                      tmp.IPV4.PRO  := X(7 downto 0);
    
    when 15       =>  tmp.IPV4.SUM  := unsigned(X);
    when 14      =>  tmp.IPV4.SRC( 31 downto 16) := X;
    when 13       =>  tmp.IPV4.SRC( 15 downto 0)  := X; 
    when 12       =>  tmp.IPV4.DEST(31 downto 16) := X;
    when 11       =>  tmp.IPV4.DEST(15 downto 0)  := X;
    when 10       =>  tmp.IPV4.OPT(23 downto 8)  := X;  
    when  9       =>  tmp.IPV4.OPT(7 downto 0)  := X(15 downto 8);  
    -- UDP HDR  
    when  8       =>  tmp.UDP.SRC_PORT  := X;
    when  7       =>  tmp.UDP.DEST_PORT := X;
    when  6       =>  tmp.UDP.MLEN      := unsigned(X); 
    when  5       =>  tmp.UDP.SUM       := unsigned(X);
    -- EB HDR 
    when  4       =>  tmp.EB.PRO        := X(15 downto 8);
                      tmp.EB.SAD        := unsigned(X(7 downto 0));
    when  3       =>  tmp.EB.ADINC      := unsigned(X(7 downto 0));
                      tmp.EB.RCNT       := unsigned(X(7 downto 0));
    when  2       =>  tmp.EB.ACKF       := X(8);
                      tmp.EB.SWABF      := X(0);
    when  1       =>  tmp.EB.RPORT      := X(15 downto 8);
                      tmp.EB.RREM       := unsigned(X(7 downto 0));
    when  0       =>  tmp.EB.SEQN       := unsigned(X(7 downto 0));
    
    when others   =>  null;
  end case;                   
  
  return tmp;               
end SLV16_TO_EB_PACK_HDR;

----------------------------------------------------------------------------------

end package body;




