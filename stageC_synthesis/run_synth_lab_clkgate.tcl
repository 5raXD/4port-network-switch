puts ""
puts "=========================================="
puts " Synthesis - 4-Port Network Switch"
puts " Clock Gating: ENABLED"
puts "=========================================="
puts ""

set_host_options -max_cores 4

set DESIGN_NAME "switch_4port_synth"
set WORK_DIR [pwd]
set TECH_FILE "/data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m.tf"
create_lib -technology $TECH_FILE -ref_libs { \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_hvt.ndm \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_lvt.ndm \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_rvt.ndm \
} switch_clkgate.dlib

open_lib switch_clkgate.dlib
report_ref_libs

# Parasitic models
read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmax.lv.tluplus -name Cmax
read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmin.lv.tluplus -name Cmin
save_lib
puts "\n>>> Reading RTL files..."
analyze -format sverilog {switch_port_synth.sv switch_4port_synth.sv}

elaborate $DESIGN_NAME
set_top_module $DESIGN_NAME
set_app_options -name compile.flow.autoungroup -value false
save_block -as switch_clkgate/elaborate
# ENABLE CLOCK GATING
puts "\n>>> Enabling clock gating..."
set_app_options -name clock_opt.flow.enable_ccd -value true
set_app_options -name power.enable_clock_gating -value true
set_clock_gating_style -sequential_cell latch -minimum_bitwidth 4 -max_fanout 32
set_app_options -name compile.optimization.insert_clock_gating -value true
# MCMM setup
puts "\n>>> Setting up corners..."
remove_corners -all
remove_modes -all
remove_scenarios -all

# Create Corners
create_corner Fast
create_corner Slow
set_parasitics_parameters -early_spec Cmin -late_spec Cmin -corners {Fast}
set_parasitics_parameters -early_spec Cmax -late_spec Cmax -corners {Slow}

# Create Mode and Scenarios
create_mode FUNC
current_mode FUNC
create_scenario -mode FUNC -corner Fast -name FUNC_Fast
create_scenario -mode FUNC -corner Slow -name FUNC_Slow

puts "\n>>> Applying timing constraints..."
current_scenario FUNC_Fast
source ${WORK_DIR}/switch.sdc
current_scenario FUNC_Slow
source ${WORK_DIR}/switch.sdc
# Floorplan Constraints
set_auto_floorplan_constraints -core_utilization 0.7 -side_ratio {1 1} -core_offset 2
puts "\n>>> Running synthesis with clock gating (logic optimization)..."
compile_fusion -to logic_opto
save_block -as switch_clkgate/logic_opto

puts "\n>>> Running synthesis with clock gating (final optimization)..."
compile_fusion -to final_opto
save_block -as switch_clkgate/final_opto

puts "\n>>> Generating reports..."
report_timing -max_paths 10 -nosplit > ${WORK_DIR}/timing_report_clkgate.txt
report_timing -delay_type min -max_paths 10 -nosplit > ${WORK_DIR}/timing_hold_report_clkgate.txt
report_qor -nosplit > ${WORK_DIR}/qor_report_clkgate.txt
report_area -nosplit > ${WORK_DIR}/area_report_clkgate.txt
report_area -hierarchy -nosplit > ${WORK_DIR}/area_hierarchy_report_clkgate.txt
report_power -nosplit > ${WORK_DIR}/power_report_clkgate.txt
report_clock_gating -nosplit > ${WORK_DIR}/clock_gating_report.txt
report_design -nosplit > ${WORK_DIR}/design_report_clkgate.txt

puts "\n>>> Exporting netlist and SDF..."
write_verilog ${WORK_DIR}/switch_4port_netlist_clkgate.v -hierarchy all
write_sdc -output ${WORK_DIR}/switch_synth_clkgate.sdc
write_sdf -output ${WORK_DIR}/switch_clkgate.sdf

puts ""
puts "=========================================="
puts " Synthesis Complete (WITH CLOCK GATING)"
puts " Netlist: switch_4port_netlist_clkgate.v"
puts " SDF:     switch_clkgate.sdf"
puts " Reports: *_clkgate.txt"
puts " Clock Gating Report: clock_gating_report.txt"
puts "=========================================="
puts ""

