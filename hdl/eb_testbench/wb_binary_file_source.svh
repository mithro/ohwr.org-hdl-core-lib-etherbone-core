`ifndef __WB_PACKET_SOURCE_SVH
 `define __WB_PACKET_SOURCE_SVH

`include "simdrv_defs.svh"
`include "eth_packet.svh"
`include "if_wishbone_accessor.svh"

`include "wb_fabric_defs.svh"

virtual class EthPacketSource;
   static int _null  = 0;

   pure virtual task send(ref EthPacket pkt, ref int result = _null);      
endclass // PacketSource


class WBPacketSource extends EthPacketSource;
   protected CWishboneAccessor m_acc;

    function new(CWishboneAccessor acc);
      m_acc  = acc;
   endfunction // new


   
   
   task send(ref EthPacket pkt, ref int result = _null);

`define EOF 16'HFFFF
`define MEM_SIZE 750



reg [15:0] pdata[0:`MEM_SIZE];
reg [80*8:1] file_name;
int r, i, j, len, file;
      wb_cycle_t cyc;
      wb_xfer_t xf;

    file_name = "etherbone-v4-req.pcap";
    file = $fopen(file_name, "rb");
    i = $fgetc(file);
    $display("test char %0d \n", i);
   
    i = $fseek(file, 40, 0);
    i = $ftell(file);
    $display("ftell %0d\n", i);
    len = $fread(pdata[0], file);
    $display("Loaded %0d entries \n", len);
    i = $fcloser(file);



      
      cyc.ctype  = PIPELINED;
      cyc.rw     = 1;
      
 


      j = 0;
      for(i=0; j < len; i++)
      begin
           xf.a          = WRF_DATA;
           if(i==len-1 && (len&1))
             begin
                xf.size  = 1;
                xf.d     = pdata[i] >> 8;
             end else begin
                xf.size  = 2;
                xf.d     = pdata[i];
             end
           j += xf.size;
           cyc.data.push_back(xf); 

      end


      m_acc.put(cyc);
      m_acc.get(cyc);

      result  = cyc.result;
      
   endtask // send
   

      
      

endclass // WBPacketSource



`endif
