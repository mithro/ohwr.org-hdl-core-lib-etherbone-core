onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/slave_rx_stream_i.cyc {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.stb {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.adr {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.sel {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.we {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_i.dat {-height 15 -radix hexadecimal}} /tb_eb3/dut/slave_rx_stream_i
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/slave_rx_stream_o.ack {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_o.err {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_o.rty {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_o.stall {-height 15 -radix hexadecimal} /tb_eb3/dut/slave_rx_stream_o.dat {-height 15 -radix hexadecimal}} /tb_eb3/dut/slave_rx_stream_o
add wave -noupdate -radix hexadecimal /tb_eb3/dut/master_tx_stream_i
add wave -noupdate -radix hexadecimal /tb_eb3/dut/master_tx_stream_o
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/master_ic_o.cyc {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.stb {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.adr {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.sel {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.we {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_o.dat {-height 15 -radix hexadecimal}} /tb_eb3/dut/master_ic_o
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb3/dut/master_ic_i.ack {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_i.err {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_i.rty {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_i.stall {-height 15 -radix hexadecimal} /tb_eb3/dut/master_ic_i.dat {-height 15 -radix hexadecimal}} /tb_eb3/dut/master_ic_i
add wave -noupdate -radix hexadecimal /tb_eb3/dut/byte_count_rx_i
add wave -noupdate -radix hexadecimal /tb_eb3/dut/byte_count_tx_o
add wave -noupdate -color Gold -itemcolor Gold /tb_eb3/dut/state_rx
add wave -noupdate -color Gold -itemcolor Gold /tb_eb3/dut/state_tx
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {208966 ps} 0}
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
WaveRestoreZoom {12427 ps} {426939 ps}
