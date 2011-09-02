# Constrain clock port clk with a 10-ns requirement

create_clock -period 8 [get_ports clk_i]

# Automatically apply a generate clock on the output of phase-locked loops (PLLs)
# This command can be safely left in the SDC even if no PLLs exist in the design

derive_pll_clocks

set_multicycle_path -setup -end -from [get_pins EB_CORE:master|eb_mini_master:\master:minimaster|s_rd_ops|clk] -to [get_pins EB_CORE:master|eb_mini_master:\master:minimaster|TOL_o|*] 2

