
EBPROTO = Proto ("myproto", "Etherbone")

local f = EBPROTO.fields
local formats = { "Text", "Binary", [10] = "Special"}

f.magic = ProtoField.uint16 ("myproto.magic", "Magic", base.HEX, nil, 0xFFFF)
f.ver = ProtoField.uint8 ("myproto.ver", "Version", base.DEC, nil, 0xF0)
f.probe = ProtoField.uint8 ("myproto.probe", "Probe", base.BOOL, nil, 0x01)
f.buswidth = ProtoField.uint8 ("myproto.buswidth", "BusWidth", base.DEC, nil, 0xF0)
f.adrwidth = ProtoField.uint8 ("myproto.adrwidth", "AddrWidth", base.DEC, nil, 0x0F)


f.format = ProtoField.uint8 ("myproto.format", "Format", nil, formats, 0x0F)
f.mydata = ProtoField.bytes ("myproto.mydata", "Data")

-- The dissector function
function EBPROTO.dissector (buffer, pinfo, tree)
-- Adding fields to the tree
local subtree = tree:add (EBPROTO, buffer())
local offset = 0
local msgid = buffer (offset, 4)
subtree:add (f.msgid, msgid)
subtree:append_text (", Message Id: " .. msgid:uint())
offset = offset + 4
subtree:add (f.magic, buffer(offset, 1))
subtree:add (f.format, buffer(offset, 1))
offset = offset + 1
subtree:add (f.mydata, buffer(offset))
end

-- Register the dissector
udp_table = DissectorTable.get ("udp.port")
udp_table:add (60368, EBPROTO)