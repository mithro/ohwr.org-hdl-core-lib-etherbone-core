onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /ecb_tb/dut/clk_i
add wave -noupdate -radix hexadecimal /ecb_tb/dut/nrst_i
add wave -noupdate -radix hexadecimal /ecb_tb/dut/slv16_i
add wave -noupdate -radix hexadecimal /ecb_tb/dut/slv16_o
add wave -noupdate -radix hexadecimal /ecb_tb/dut/en_cnt_i
add wave -noupdate -radix hexadecimal /ecb_tb/dut/s_slv16_i
add wave -noupdate -radix hexadecimal /ecb_tb/dut/s_slv16_o
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/ecb_tb/dut/test_hdr.ipv4 {-radix hexadecimal -expand} /ecb_tb/dut/test_hdr.ipv4.ver {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.ihl {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.tos {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.id {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.flg {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.fro {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.ttl {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.pro {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.tol {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.sum {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.src {-radix hexadecimal} /ecb_tb/dut/test_hdr.ipv4.dest {-radix hexadecimal} /ecb_tb/dut/test_hdr.udp {-radix hexadecimal -expand} /ecb_tb/dut/test_hdr.udp.src_port {-radix hexadecimal} /ecb_tb/dut/test_hdr.udp.dest_port {-radix hexadecimal} /ecb_tb/dut/test_hdr.udp.mlen {-radix hexadecimal} /ecb_tb/dut/test_hdr.udp.sum {-radix hexadecimal} /ecb_tb/dut/test_hdr.eb {-radix hexadecimal}} /ecb_tb/dut/test_hdr
add wave -noupdate -radix hexadecimal /ecb_tb/dut/cnt_hdr
add wave -noupdate -radix unsigned /ecb_tb/dut/cnt
add wave -noupdate -radix hexadecimal /ecb_tb/dut/done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
configure wave -namecolwidth 116
configure wave -valuecolwidth 108
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
WaveRestoreZoom {0 ps} {305152 ps}
