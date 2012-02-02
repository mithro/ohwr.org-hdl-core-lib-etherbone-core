--! @file etherbone.lua
--! @brief Wireshark protocol dissector for EtherBone 0.2 packets
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
---------------------------------------------------------------------------------


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

--- Returns HEX representation of num
function num2hex(num)
    local hexstr = '0123456789abcdef'
    local s = ''
    while num > 0 do
        local mod = math.fmod(num, 16)
        s = string.sub(hexstr, mod+1, mod+1) .. s
        num = math.floor(num / 16)
    end
    if s == '' then s = '0' end
    return s
end

-- Declare protocol
proto_eb = Proto("eb", "Etherbone")


-- Declare its fields
local eb       = proto_eb.fields
eb.hdr  	= ProtoField.uint32("eb.hdr"    , "EB Hdr	"            , base.HEX)
eb.hdr_magic  	= ProtoField.uint16("eb.hdr.magic", "Magic	", base.HEX, nil, 0xFFFF)
eb.hdr_ver 		= ProtoField.uint16("eb.hdr.ver", 	"Version	", base.HEX, nil, 0xF000)
eb.hdr_res 		= ProtoField.uint16("eb.hdr.res", 	"Reserved	", base.HEX, nil, 0x0E00)
eb.hdr_probe	= ProtoField.uint16("eb.hdr.probe", 	"Probe	", base.DEC, VALS_BOOL, 0x0100)
eb.hdr_adrs     = ProtoField.uint16("eb.hdr.adrw", 	"AdrSize	", base.DEC, VALS_SIZE , 0x00F0)
eb.hdr_ports    = ProtoField.uint16("eb.hdr.portw", 	"PortSize	", base.DEC, VALS_SIZE , 0x000F)

eb.rec 				= ProtoField.bytes("eb.rec", 			"EB Record	", base.HEX)
eb.rec_hdr 			= ProtoField.uint32("eb.rec.hdr", 			"EB Record Hdr	", base.HEX)
eb.rec_hdr_flags	= ProtoField.uint16("eb.rec.hdr.flags", 			"Flags	", base.HEX)

eb.rec_hdr_flags_adrcfg 	= ProtoField.uint16("eb.rec.hdr.flags.adrcfg",	"ReplyToCfgSpace	", base.DEC, VALS_BOOL, 0x8000)
eb.rec_hdr_flags_rbacfg 	= ProtoField.uint16("eb.rec.hdr.adrcfg",	"ReadFromCfgSpace	", base.DEC, VALS_BOOL, 0x4000)
eb.rec_hdr_flags_rdfifo 	= ProtoField.uint16("eb.rec.hdr.adrcfg",	"ReadFIFO		", base.DEC, VALS_BOOL, 0x2000)
eb.rec_hdr_flags_res0 	= ProtoField.uint16("eb.rec.hdr.res0",		"Reserved		", base.HEX, nil, 0x1000)
eb.rec_hdr_flags_dropcyc 	= ProtoField.uint16("eb.rec.hdr.adrcfg", 	"DropCycle		", base.DEC, VALS_BOOL, 0x0800)
eb.rec_hdr_flags_wbacfg 	= ProtoField.uint16("eb.rec.hdr.adrcfg",	"WriteToCfgSpace	", base.DEC, VALS_BOOL, 0x0400)
eb.rec_hdr_flags_wrfifo 	= ProtoField.uint16("eb.rec.hdr.adrcfg",	"WriteFIFO		", base.DEC, VALS_BOOL, 0x0200)
eb.rec_hdr_flags_res1 	= ProtoField.uint16("eb.rec.hdr.res1",		"Reserved		", base.HEX, nil, 0x01F0)

eb.rec_hdr_wr 	= ProtoField.uint16("eb.rec.hdr.wr",		"WriteOps", base.DEC)
eb.rec_hdr_rd 	= ProtoField.uint16("eb.rec.hdr.rd",		"ReadOps	", base.DEC)

eb.rec_writes	= ProtoField.bytes("eb.rec.writes", 			"Writes	", base.HEX)
eb.rec_wrsadr	= ProtoField.uint32("eb.rec.wrsadr", 			"WriteStartAddr	", base.HEX)
eb.rec_wrdata	= ProtoField.uint32("eb.rec.wrdata", 			"WriteValue	", base.HEX)

eb.rec_reads	= ProtoField.bytes("eb.rec.reads", 				"Reads	", base.HEX)
eb.rec_rdbadr	= ProtoField.uint32("eb.rec.rdbadr", 			"ReadBackAddr	", base.HEX)
eb.rec_rddata	= ProtoField.uint32("eb.rec.rddata", 			"ReadAddr	", base.HEX)

eb.zeros	= ProtoField.bytes("eb.zeros", 				"Padding	", base.HEX, nil, 0x00000000)

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
        
		local magic = num2hex(tonumber(buf(0,2):uint())) 
		if(magic == "4e6f") then -- is this a valid etherbone packet ?
		
			t_hdr:add( eb.hdr_magic, 	buf(0,2))                      -- magic
			t_hdr:add( eb.hdr_ver, 		buf(2,1))                      -- version
			t_hdr:add( eb.hdr_res, 		buf(2,2))						-- reserved bits
			t_hdr:add( eb.hdr_probe, 	buf(2,2))                      -- probe
			
			t_hdr:add( eb.hdr_adrs, 	buf(2,2))                      -- supported addr size
			t_hdr:add( eb.hdr_ports, 	buf(2,2))                      -- supported port size
			
			
			local probe=tonumber(buf(2,1):uint())
			if(tonumber(bit.tohex(bit.band(probe,0x01))) == 1) then
				t_hdr:add( "Abbruch" )
			else
				--do something else
				
				local offset = 4
				local recordcnt = 0
				local zerocount = 0
				while (offset < buf:len()) do
		
			
					
					local wr = tonumber(buf(offset+2,1):uint())
					local rd = tonumber(buf(offset+3,1):uint())	
					
					local rdadr = 0
					local wradr = 0
					if(rd > 0) then
						rdadr = 1
					end
					if(wr > 0) then
						wradr = 1
					end
					
						
					-- t_rec = t:add(wr)
					-- t_rec = t:add(rd)
					-- t_rec = t:add(offset)
					-- t_rec = t:add((1+rd+wr+rdadr+wradr)*4)
					if((wr == 0) and (rd == 0)) then
						zerocount = zerocount +4
						offset = offset + 4
					else
						if(zerocount > 0) then
							local t_pad = t:add( eb.zeros, buf(offset-zerocount,zerocount))
							--t_pad:append_text("	"..tostring(zerocount))
						end
						local t_rec = t:add( "EB Record "..tostring(recordcnt).."	(W"..tostring(wr).."	R"..tostring(rd)..")", buf(offset-zerocount, ((1+rd+wr+rdadr+wradr)*4)))
						recordcnt = recordcnt + 1
						
						
						zerocount = 0
						local t_rec_hdr = t_rec:add( eb.rec_hdr, buf(offset,4))
						local t_rec_hdr_flags = t_rec_hdr:add( eb.rec_hdr_flags, buf(offset,2))
						t_rec_hdr_flags:add( eb.rec_hdr_flags_adrcfg, buf(offset,2)) 
						t_rec_hdr_flags:add( eb.rec_hdr_flags_rbacfg, buf(offset,2)) 
						t_rec_hdr_flags:add( eb.rec_hdr_flags_rdfifo, buf(offset,2)) 
						t_rec_hdr_flags:add( eb.rec_hdr_flags_res0, buf(offset,2)) 
						t_rec_hdr_flags:add( eb.rec_hdr_flags_dropcyc , buf(offset,2)) 
						t_rec_hdr_flags:add( eb.rec_hdr_flags_wbacfg , buf(offset,2)) 
						t_rec_hdr_flags:add( eb.rec_hdr_flags_wrfifo, buf(offset,2)) 
						t_rec_hdr_flags:add( eb.rec_hdr_flags_res1, buf(offset,2))
						
						
						
						
						t_rec_hdr:add( eb.rec_hdr_wr, buf(offset+2,1)) 
						t_rec_hdr:add( eb.rec_hdr_rd, buf(offset+3,1))
						offset = offset +4
						local tmp_offset
						
						if(wr > 0) then
							
							local t_writes = t_rec:add( eb.rec_writes, buf(offset,wr*4+1))
							t_writes:add( eb.rec_wrsadr, buf(offset,4))
							offset = offset +4
							
							tmp_offset = offset
							while (tmp_offset < offset+wr*4) do
								t_writes:add( eb.rec_wrdata, buf(tmp_offset,4))
								tmp_offset = tmp_offset +4
							end
							offset = tmp_offset
							
						end
						if(rd > 0) then
							local t_reads = t_rec:add( eb.rec_reads, buf(offset,rd*4+1))
							t_reads:add( eb.rec_rdbadr, buf(offset,4))
							offset = offset +4
							
							tmp_offset = offset
							while (tmp_offset < offset+rd*4) do
								t_reads:add( eb.rec_rddata, buf(tmp_offset,4))
								tmp_offset = tmp_offset +4
							end
							offset = tmp_offset
						end
					end
				end	
		
			end
			
		else
			return 0
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
