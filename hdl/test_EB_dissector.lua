EBPROTO = Proto ("test1", "Etherbone")

local f = EBPROTO.fields
local formats = { "Text", "Binary", [10] = "Special"}

f.magic = ProtoField.uint16 ("test1.magic", "Magic", base.HEX, nil, 0xFFFF)
f.ver = ProtoField.uint8 ("test1.ver", "Version", base.DEC, nil, 0xF0)
f.probe = ProtoField.uint8 ("test1.probe", "Probe", base.BOOL, nil, 0x01)
f.buswidth = ProtoField.uint8 ("test1.buswidth", "BusWidth", base.DEC, nil, 0xF0)
f.adrwidth = ProtoField.uint8 ("test1.adrwidth", "AddrWidth", base.DEC, nil, 0x0F)


f.format = ProtoField.uint8 ("test1.format", "Format", nil, formats, 0x0F)
f.mydata = ProtoField.bytes ("test1.mydata", "Data")

-- The dissector function
function EBPROTO.dissector (buffer, pinfo, root)
-- Adding fields to the tree
local subtree = root:add (EBPROTO, buffer())
local offset = 0
local magic = buffer:range(offset, 2) 
subtree:add(f.magic, magic))
subtree:append_text ("Magic: 0x" .. tostring('0x'..buffer:range(offset, 2), 16))
offset = offset + 4
--subtree:add (f.ver, buffer:range(offset, 1))
--subtree:add (f.probe, buffer(offset, 1))
--offset = offset + 1
--subtree:add (f.buswidth, buffer:range(offset, 1))
---subtree:add (f.adrwidth, buffer:range(offset, 1))
--offset = offset + 1
--subtree:add (f.mydata, buffer:range(offset))
end

-- Register the dissector
udp_table = DissectorTable.get ("udp.port")
udp_table:add (60368, EBPROTO)