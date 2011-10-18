onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /tb_eb5/s_clk_i
add wave -noupdate -radix hexadecimal -expand -subitemconfig {/tb_eb5/s_ebm_rx_i.cyc {-height 15 -radix hexadecimal} /tb_eb5/s_ebm_rx_i.stb {-height 15 -radix hexadecimal} /tb_eb5/s_ebm_rx_i.adr {-height 15 -radix hexadecimal} /tb_eb5/s_ebm_rx_i.sel {-height 15 -radix hexadecimal} /tb_eb5/s_ebm_rx_i.we {-height 15 -radix hexadecimal} /tb_eb5/s_ebm_rx_i.dat {-height 15 -radix hexadecimal}} /tb_eb5/s_ebm_rx_i
add wave -noupdate -radix hexadecimal /tb_eb5/s_ebm_rx_o.stall
add wave -noupdate -radix hexadecimal /tb_eb5/s_ebm_rx_o
add wave -noupdate -radix hexadecimal /tb_eb5/s_ebm_tx_i
add wave -noupdate -radix hexadecimal /tb_eb5/s_ebm_tx_o
add wave -noupdate -radix hexadecimal /tb_eb5/s_ebs_rx_i
add wave -noupdate -radix hexadecimal /tb_eb5/s_ebs_rx_o
add wave -noupdate -radix hexadecimal /tb_eb5/s_ebs_tx_i
add wave -noupdate -radix hexadecimal /tb_eb5/s_ebs_tx_o
add wave -noupdate -radix hexadecimal /tb_eb5/s_master_ic_i
add wave -noupdate -radix hexadecimal /tb_eb5/s_master_ic_o
add wave -noupdate -radix hexadecimal /tb_eb5/s_nrst_i
add wave -noupdate -radix hexadecimal /tb_eb5/master/master/minimaster/clock_div
add wave -noupdate -color Gold -radix hexadecimal /tb_eb5/master/master/minimaster/state_rx
add wave -noupdate -color Cyan -radix hexadecimal /tb_eb5/master/master/minimaster/state_tx
add wave -noupdate -color Magenta -radix hexadecimal /tb_eb5/slave/slave/eb/state_rx
add wave -noupdate -color Magenta -radix hexadecimal /tb_eb5/slave/slave/eb/state_tx
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/almost_empty
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/almost_full
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/clock
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/data
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/empty
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/full
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/q
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/rdreq
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/sclr
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/sub_wire0
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/sub_wire1
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/sub_wire2
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/sub_wire3
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/sub_wire4
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/sub_wire5
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/usedw
add wave -noupdate -expand -group minim_rx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/rx_fifo/wrreq
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/clock
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/data
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/sclr
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/wrreq
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/almost_empty
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/almost_full
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/empty
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/full
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/usedw
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/sub_wire0
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/sub_wire1
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/sub_wire2
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/sub_wire3
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/sub_wire4
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/sub_wire5
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/rdreq
add wave -noupdate -group slave_rx_fifo -radix hexadecimal /tb_eb5/slave/slave/eb/rx_fifo/q
add wave -noupdate -group minim_tx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/s_tx_fifo_data
add wave -noupdate -group minim_tx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/s_tx_fifo_gauge
add wave -noupdate -group minim_tx_fifo -radix hexadecimal /tb_eb5/master/master/minimaster/s_tx_fifo_we
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 2} {1491975 ps} 0}
configure wave -namecolwidth 320
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
WaveRestoreZoom {6024210 ps} {6246442 ps}
