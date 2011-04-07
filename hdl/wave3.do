onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -color {Orange Red} -itemcolor {Orange Red} /tb_eb3/s_clk_i
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/slave_rx_stream_i.cyc {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.stb {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.adr {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.sel {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.we {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.dat {-height 15 -radix hexadecimal}} /tb_eb3/dut/slave_rx_stream_i
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/slave_rx_stream_o.ack {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_o.err {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_o.rty {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_o.stall {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_o.dat {-height 15 -radix hexadecimal}} /tb_eb3/dut/slave_rx_stream_o
add wave -noupdate -color Gold -itemcolor Gold /tb_eb3/dut/state_rx
add wave -noupdate -color Gold -itemcolor Gold /tb_eb3/dut/state_tx
add wave -noupdate -radix hexadecimal /tb_eb3/dut/master_tx_stream_i
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/master_ic_o.cyc {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.stb {-color Cyan -height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.adr {-color Magenta -height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.sel {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.we {-color Cyan -height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.dat {-color Magenta -height 15 -radix hexadecimal}} /tb_eb3/dut/master_ic_o
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/master_ic_i.ack {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_i.err {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_i.rty {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_i.stall {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_i.dat {-height 15 -radix hexadecimal}} /tb_eb3/dut/master_ic_i
add wave -noupdate -radix unsigned /tb_eb3/dut/byte_count_rx_i
add wave -noupdate -radix hexadecimal /tb_eb3/dut/byte_count_tx_o
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/master_tx_stream_o.cyc {-height 15 -radix hexadecimal} /tb_eb3/dut/master_tx_stream_o.stb {-height 15 -radix hexadecimal} /tb_eb3/dut/master_tx_stream_o.adr {-height 15 -radix hexadecimal} /tb_eb3/dut/master_tx_stream_o.sel {-height 15 -radix hexadecimal} /tb_eb3/dut/master_tx_stream_o.we {-height 15 -radix hexadecimal} /tb_eb3/dut/master_tx_stream_o.dat {-height 15 -radix hexadecimal}} /tb_eb3/dut/master_tx_stream_o
add wave -noupdate -radix hexadecimal /tb_eb3/dut/wb_addr_count
add wave -noupdate -color Gold -itemcolor Gold -radix hexadecimal /tb_eb3/dut/slave_rx_stream_i.dat
add wave -noupdate -radix hexadecimal /tb_eb3/dut/slave_rx_stream_o.ack
add wave -noupdate -radix unsigned /tb_eb3/dut/rx_eb_byte_count
add wave -noupdate -radix unsigned /tb_eb3/dut/tx_eb_byte_count
add wave -noupdate -radix hexadecimal /tb_eb3/dut/master_tx_stream_o.stb
add wave -noupdate -color Magenta -itemcolor Magenta /tb_eb3/dut/debug_byte_diff
add wave -noupdate -color Magenta -itemcolor Magenta /tb_eb3/dut/debug_diff
add wave -noupdate -radix unsigned /tb_eb3/dut/debugsum
add wave -noupdate /tb_eb3/len
add wave -noupdate /tb_eb3/s_rds
add wave -noupdate /tb_eb3/s_wrs
add wave -noupdate -radix unsigned /tb_eb3/dut/s_byte_count_rx_i
add wave -noupdate -color {Orange Red} -itemcolor {Orange Red} /tb_eb3/state
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/rx_eb_hdr.eb_magic {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_hdr.ver {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_hdr.reserved1 {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_hdr.probe {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_hdr.addr_size {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_hdr.port_size {-height 15 -radix hexadecimal}} /tb_eb3/rx_eb_hdr
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/rx_eb_cyc.reserved2 {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_cyc.rd_fifo {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_cyc.rd_cnt {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_cyc.reserved3 {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_cyc.wr_fifo {-height 15 -radix hexadecimal} /tb_eb3/rx_eb_cyc.wr_cnt {-height 15 -radix hexadecimal}} /tb_eb3/rx_eb_cyc
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {590276 ps} 0}
configure wave -namecolwidth 199
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {829024 ps}
