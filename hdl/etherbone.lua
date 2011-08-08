-- value-string maps for the protocol fields

local VALS_BAR  = {[0x11] = "Whiskey", [0x12] = "Rum", [0x13] =
"Vodka", [0x14] = "Gin"}
local VALS_BOOL = {[0] = "False", [1] = "True"}
local VALS_RES = {[0] = "not set", [1] = "set, bad data?"}
local VALS_SIZE = {
[0x00] = "Bad Value",
[0x01] = "8 bit",
[0x02] = "16 bit",
[0x03] = "16,8 bit",
[0x04] = "32 bit",
[0x05] = "32,8 bit",
[0x06] = "32,16 bit",
[0x07] = "32,16,8 bit",
[0x08] = "64 bit",
[0x09] = "64,8 bit",
[0x0A] = "64,16 bit",
[0x0B] = "64,16,8 bit",
[0x0C] = "64,32 bit",
[0x0D] = "64,32,8 bit",
[0x0E] = "64,32,16 bit",
[0x0F] = "64,32,16,8 bit",
}

-- Declare protocol
proto_eb = Proto("eb", "Etherbone")


-- Declare its fields
local eb       = proto_eb.fields
eb.hdr  	= ProtoField.uint32("eb.hdr"    , "EB Hdr"            , base.HEX)
eb.hdr_magic  	= ProtoField.uint16("eb.hdr.magic", "	    Magic	", base.HEX)
eb.hdr_ver 		= ProtoField.uint8("eb.hdr.ver", 	"Version	", base.HEX, nil, 0xF0)
eb.hdr_res 		= ProtoField.uint8("eb.hdr.res", 	"Reserved	", base.HEX, nil, 0x0E)
eb.hdr_probe	= ProtoField.uint8("eb.hdr.probe", 	"Probe	", base.DEC, VALS_BOOL, 0x01)
eb.hdr_adrs     = ProtoField.uint8("eb.hdr.adrw", 	"AdrSize	", base.DEC, VALS_SIZE , 0xF0)
eb.hdr_ports    = ProtoField.uint8("eb.hdr.portw", 	"PortSize	", base.DEC, VALS_SIZE , 0x0F)

eb.rec 				= ProtoField.bytes("eb.rec", 			"EB Record	", base.HEX)
eb.rec_hdr 			= ProtoField.uint32("eb.rec_hdr", 			"EB Record Hdr	", base.HEX)
eb.rec_hdr_adrcfg 	= ProtoField.uint16("eb.rec_hdr.adrcfg",	"AddressConfig	", base.DEC, VALS_BOOL, 0x8000)
eb.rec_hdr_rbacfg 	= ProtoField.uint16("eb.rec_hdr.adrcfg",	"ReadBackAddrCfg	", base.DEC, VALS_BOOL, 0x4000)
eb.rec_hdr_rdfifo 	= ProtoField.uint16("eb.rec_hdr.adrcfg",	"ReadFIFO		", base.DEC, VALS_BOOL, 0x2000)
eb.rec_hdr_res0 	= ProtoField.uint16("eb.rec_hdr.res0",		"Reserved		", base.HEX, nil, 0x1000)
eb.rec_hdr_dropcyc 	= ProtoField.uint16("eb.rec_hdr.adrcfg", 	"DropCycle		", base.DEC, VALS_BOOL, 0x0800)
eb.rec_hdr_wbacfg 	= ProtoField.uint16("eb.rec_hdr.adrcfg",	"WriteBackAddrCfg	", base.DEC, VALS_BOOL, 0x0400)
eb.rec_hdr_wrfifo 	= ProtoField.uint16("eb.rec_hdr.adrcfg",	"WriteFIFO		", base.DEC, VALS_BOOL, 0x0200)
eb.rec_hdr_res1 	= ProtoField.uint16("eb.rec_hdr.res1",		"Reserved		", base.HEX, nil, 0x01F0)

eb.rec_hdr_wr 	= ProtoField.uint16("eb.rec.hdr.wr",		"		      Writes		", base.DEC)
eb.rec_hdr_rd 	= ProtoField.uint16("eb.rec.hdr.rd",		"		      Reads		", base.DEC)

eb.rec_writes	= ProtoField.bytes("eb.rec.writes", 			"Writes	", base.HEX)
eb.rec_wrsadr	= ProtoField.uint32("eb.rec.wrsadr", 			"WriteStartAddr	", base.HEX)
eb.rec_wrdata	= ProtoField.uint32("eb.rec.wrdata", 			"WriteValue	", base.HEX)

eb.rec_reads	= ProtoField.bytes("eb.rec.reads", 				"Reads	", base.HEX)
eb.rec_rdbadr	= ProtoField.uint32("eb.rec.rdbadr", 			"ReadBackAddr	", base.HEX)
eb.rec_rddata	= ProtoField.uint32("eb.rec.rddata", 			"ReadBAddr	", base.HEX)



-- Define the dissector
function proto_eb.dissector(buf, pinfo, tree)

        -- min length, 4 for eb hdr with probe
        local EXPECTED_LENGTH = 4
		
		
        if (buf:len() < EXPECTED_LENGTH) then
                -- not ours, let it go to default Data dissector
                return 0
        end
		
		
		local mylen = buf:len()
        pinfo.cols.protocol = "eb"

        -- add our packet to the tree root...we'll add fields to its subtree
        local t = tree:add( proto_eb, buf(0, mylen) )
		local t_hdr = t:add( eb.hdr, buf(0,4) )          -- hdr
        
		t_hdr:add( eb.hdr_magic, buf(0,2) )                      -- magic
        t_hdr:add( eb.hdr_ver, buf(2,1) )                      -- version
		t_hdr:add( eb.hdr_probe, buf(2,1) )                      -- version
        t_hdr:add( eb.hdr_res, buf(2,1))
		t_hdr:add( eb.hdr_adrs, buf(3,1) )                      -- adr
		t_hdr:add( eb.hdr_ports, buf(3,1) )                      -- port
		
		
		local probe=tonumber(buf(2,1):uint())
		if(tonumber(bit.tohex(bit.band(probe,0x01))) == 1) then
			t_hdr:add( "Abbruch" )
		else
			--do something else
			t_hdr:add( "Hello" )
			local offset = 4
			
			--while offset+4 < buf:len()) do
				
		
				
				
				local rd = tonumber(buf(offset+2,1):uint())	
				local wr = tonumber(buf(offset+3,1):uint())
				local rdadr = 0
				local wradr = 0
				if(rd > 0) then
					rdadr = 1
				end
				if(wr > 0) then
					wradr = 1
				end
				
				
				local t_rec = t:add( eb.rec, buf(offset, offset+((1+rd+wr+rdadr+wradr)*4)))
				local t_rec_hdr = t_rec:add( eb.rec_hdr, buf(offset,4))
				
				t_rec_hdr:add( eb.rec_hdr_adrcfg, buf(offset,2)) 
				t_rec_hdr:add( eb.rec_hdr_rbacfg, buf(offset,2)) 
				t_rec_hdr:add( eb.rec_hdr_rdfifo, buf(offset,2)) 
				t_rec_hdr:add( eb.rec_hdr_res0, buf(offset,2)) 
				t_rec_hdr:add( eb.rec_hdr_dropcyc , buf(offset,2)) 
				t_rec_hdr:add( eb.rec_hdr_wbacfg , buf(offset,2)) 
				t_rec_hdr:add( eb.rec_hdr_wrfifo, buf(offset,2)) 
				t_rec_hdr:add( eb.rec_hdr_res1, buf(offset,2))
				
				t_rec_hdr:add( eb.rec_hdr_wr, buf(offset+2,1)) 
				t_rec_hdr:add( eb.rec_hdr_rd, buf(offset+2,1))
				offset = offset +4
				local tmp_offset
				
				if(wr > 0) then
					
					local t_writes = t_rec:add( eb.rec_writes, buf(offset,wr*4+1))
					t_writes:add( eb.rec_wrsadr, buf(offset,4))
					offset = offset +4
					
					tmp_offset = offset
					while (tmp_offset < offset+wr*4) do
						t_writes:add( eb.rec_wrdata, buf(offset,4))
						tmp_offset = tmp_offset +4
					end
					
				end
				if(rd > 0) then
					local t_reads = t_rec:add( eb.rec_reads, buf(offset,rd*4+1))
					t_reads:add( eb.rec_rdbadr, buf(offset,4))
					offset = offset +4
					
					tmp_offset = offset
					while (tmp_offset < offset+rd*4) do
						t_reads:add( eb.rec_rddata, buf(offset,4))
						tmp_offset = tmp_offset +4
					end
				end
	
		end
		


		-- local offset = 4
		
		
		
		-- while offset <=  mylen do
		
		
		-- local rec =  buf(offset,4)
		
		-- if (buf:len() < EXPECTED_LENGTH + 4) then
                --not ours, let it go to default Data dissector
                -- return 0
        -- end
		
		
		
		
		
		
		

end

-- Register eb protocol on UDP port 22222
local tab = DissectorTable.get("udp.port")
tab:add(60368, proto_eb)