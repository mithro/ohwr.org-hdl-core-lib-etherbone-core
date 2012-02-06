force -freeze sim:/eb_config/clk_i 1 0, 0 {5000000 fs} -r {10 ns}
force -freeze sim:/eb_config/nRST_i 0 0
force -freeze sim:/eb_config/status_i 1 0, 0 {22500000 fs} -r {45 ns}
force -freeze sim:/eb_config/status_en 1 0, 0 {75000000 fs} -r {150 ns}
force -freeze sim:/eb_config/status_clr 0 0
run 20 ns
force -freeze sim:/eb_config/nRST_i 1 0

force -freeze sim:/eb_config/local_slave_i.CYC 0 0
force -freeze sim:/eb_config/local_slave_i.STB 0 0
force -freeze sim:/eb_config/local_slave_i.WE 0 0
force -freeze sim:/eb_config/local_slave_i.SEL 0 0
force -freeze sim:/eb_config/local_slave_i.DAT 0 0
force -freeze sim:/eb_config/local_slave_i.ADR 0 0

force -freeze sim:/eb_config/eb_slave_i.CYC 0 0
force -freeze sim:/eb_config/eb_slave_i.STB 0 0
force -freeze sim:/eb_config/eb_slave_i.WE 0 0
force -freeze sim:/eb_config/eb_slave_i.SEL 0 0
force -freeze sim:/eb_config/eb_slave_i.DAT 0 0
force -freeze sim:/eb_config/eb_slave_i.ADR 0 0

run 40 ns
force -freeze sim:/eb_config/local_slave_i.CYC 1 0
force -freeze sim:/eb_config/local_slave_i.STB 1 0
force -freeze sim:/eb_config/local_slave_i.WE 1 0
force -freeze sim:/eb_config/local_slave_i.SEL 0 0
force -freeze sim:/eb_config/local_slave_i.DAT x"ABCDEF00" 0
force -freeze sim:/eb_config/local_slave_i.ADR x"00000018" 0
run 20 ns
force -freeze sim:/eb_config/eb_slave_i.CYC 1 0
force -freeze sim:/eb_config/eb_slave_i.STB 1 0
force -freeze sim:/eb_config/eb_slave_i.WE 0 0
force -freeze sim:/eb_config/eb_slave_i.SEL 0 0
force -freeze sim:/eb_config/eb_slave_i.DAT 0 0
force -freeze sim:/eb_config/eb_slave_i.ADR x"00000018" 0
run 80 ns

force -freeze sim:/eb_config/local_slave_i.CYC 1 0
force -freeze sim:/eb_config/local_slave_i.STB 1 0
force -freeze sim:/eb_config/local_slave_i.WE 1 0
force -freeze sim:/eb_config/local_slave_i.SEL 0 0
force -freeze sim:/eb_config/local_slave_i.DAT x"12345678" 0
force -freeze sim:/eb_config/local_slave_i.ADR x"00000018" 0
force -freeze sim:/eb_config/eb_slave_i.CYC 1 0
force -freeze sim:/eb_config/eb_slave_i.STB 1 0
force -freeze sim:/eb_config/eb_slave_i.WE 1 0
force -freeze sim:/eb_config/eb_slave_i.SEL 0 0
force -freeze sim:/eb_config/eb_slave_i.DAT x"FF00FFAA" 0
force -freeze sim:/eb_config/eb_slave_i.ADR x"00000018" 0
run 40 ns
force -freeze sim:/eb_config/eb_slave_i.CYC 0 0
force -freeze sim:/eb_config/eb_slave_i.STB 0 0
force -freeze sim:/eb_config/eb_slave_i.WE 0 0
force -freeze sim:/eb_config/eb_slave_i.SEL 0 0
force -freeze sim:/eb_config/eb_slave_i.DAT x"FF00FFAA" 0
force -freeze sim:/eb_config/eb_slave_i.ADR x"00000018" 0
run 40 ns
noforce sim:/eb_config/status_en
force -freeze sim:/eb_config/status_en 0 0
run 10 ns
# read status reg locally ...
force -freeze sim:/eb_config/local_slave_i.CYC 1 0
force -freeze sim:/eb_config/local_slave_i.STB 1 0
force -freeze sim:/eb_config/local_slave_i.WE 0 0
force -freeze sim:/eb_config/local_slave_i.ADR x"00000000" 0
run 10 ns
force -freeze sim:/eb_config/local_slave_i.ADR x"00000004" 0
run 10 ns
force -freeze sim:/eb_config/local_slave_i.CYC 0 0
force -freeze sim:/eb_config/local_slave_i.STB 0 0
run 10 ns

# and remotely ...
force -freeze sim:/eb_config/eb_slave_i.CYC 1 0
force -freeze sim:/eb_config/eb_slave_i.STB 1 0
force -freeze sim:/eb_config/eb_slave_i.ADR x"00000000" 0
run 10 ns
force -freeze sim:/eb_config/eb_slave_i.ADR x"00000004" 0
run 10 ns
force -freeze sim:/eb_config/eb_slave_i.CYC 0 0
force -freeze sim:/eb_config/eb_slave_i.STB 0 0




