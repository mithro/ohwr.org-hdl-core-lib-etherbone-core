unit Global;

interface

uses etherbone,wrdevice_unit;

const
  First_DNSAdress = 'asl720.acc.gsi.de:8989';
  First_PortNumber= '400';

var
  myDNSAdress  :string;
  myAddress    :eb_address_t;
  myDevice     :Twrdevice;


type TWrPacket= RECORD CASE Int64 OF
              1: (wpack: Int64);
              2: (r    : PACKED RECORD
                  data : LongWord;
                  Adr  : LongWord;
                  END;);
            END;


implementation

end.
