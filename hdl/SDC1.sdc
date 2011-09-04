# Constrain clock port clk with a 10-ns requirement

create_clock -period 8 [get_ports clk_i]

# Automatically apply a generate clock on the output of phase-locked loops (PLLs)
# This command can be safely left in the SDC even if no PLLs exist in the design

derive_pll_clocks

set_multicycle_path  -to {EB_CORE:master|eb_mini_master:\master:minimaster|TOL_o[*]} -setup -end 2
set_multicycle_path  -to {EB_CORE:master|eb_mini_master:\master:minimaster|TOL_o[*]} -hold -end 1

# cut irrelevant output paths
#set_false_path -to [get_ports {sd_clk} ] -from *
#set_false_path -to [get_ports {dclk nce asdo} ] -from *
#set_false_path -to [get_ports {altera_reserved_tdo}] -from *