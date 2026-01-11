# SDC Timing Constraints for 4-Port Network Switch
# Target: 100 MHz (10ns period)

remove_sdc -design

# Clock: 10ns period = 100 MHz
set CLK_PERIOD 10
create_clock -period $CLK_PERIOD -name clk [get_ports clk]
set_clock_uncertainty -setup 0.15 [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]

# Input delays (all inputs except clock)
set_input_delay -max 0.5 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -min 0.1 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]

# Output delays
set_output_delay -max 0.5 -clock clk [all_outputs]
set_output_delay -min 0.1 -clock clk [all_outputs]

# Reset is asynchronous - no timing
set_false_path -from [get_ports rst_n]

# Design rules
set_max_transition 0.3 [current_design]
set_max_fanout 20 [current_design]
set_max_capacitance 0.5 [all_outputs]
