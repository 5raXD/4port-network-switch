# remove any constraints that were applied from previous runs:

remove_sdc -design



# Set the physical library:

set lib_name saed32hvt_ss0p75v125c


#set_current_design TOP


# Create clock object and set uncertainty

create_clock -period 10 [get_ports clk]

set_clock_uncertainty -setup 0.15 [get_clocks clk]



# Set constraints on input ports

#suppress_message UID-401

#suppress_message DCT-306



set_input_delay -max 0.5 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]




#Set constraints on output ports:

set_output_delay 0.2 -max -clock clk [all_outputs]
