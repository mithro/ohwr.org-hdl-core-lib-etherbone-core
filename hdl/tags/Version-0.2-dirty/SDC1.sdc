# Constrain clock port clk with a 10-ns requirement

create_clock -period 8 [get_ports clk_i]

# Automatically apply a generate clock on the output of phase-locked loops (PLLs)
# This command can be safely left in the SDC even if no PLLs exist in the design

derive_pll_clocks 
derive_clock_uncertainty

set_multicycle_path  -to {EB_CORE:master|eb_mini_master:\master:minimaster|TOL_o[*]} -setup -end 2
set_multicycle_path  -to {EB_CORE:master|eb_mini_master:\master:minimaster|TOL_o[*]} -hold -end 1

# cutt irrelevant input path
set_false_path -from [get_ports {nRST_i}] -to *
set_false_path -from [get_ports {altera_reserved_tdi altera_reserved_tms}] -to *


# cut irrelevant output paths
set_false_path -to [get_ports {leds_o*} ] -from *
set_false_path -to [get_ports {alive_led_o} ] -from *
set_false_path -to [get_ports {altera_reserved_tdo}] -from *