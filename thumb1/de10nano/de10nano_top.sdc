# -------------------------------------------------------------------------- #
# Timing Constraints for Tiny Thumb-1 Core on DE10-Nano
# Synopsys Design Constraints (SDC) file
# -------------------------------------------------------------------------- #

# 50 MHz clock constraint (20 ns period)
create_clock -name {FPGA_CLK1_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports {FPGA_CLK1_50}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects
derive_clock_uncertainty
