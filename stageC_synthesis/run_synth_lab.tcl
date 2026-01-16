puts ""
puts "=========================================="
puts " Synthesis - 4-Port Network Switch"
puts " Clock Gating: DISABLED"
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
} switch.dlib

open_lib switch.dlib
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
save_block -as switch/elaborate
# NO CLOCK GATING
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

set_auto_floorplan_constraints -core_utilization 0.7 -side_ratio {1 1} -core_offset 2

puts "\n>>> Running synthesis (logic optimization)..."
compile_fusion -to logic_opto
save_block -as switch/logic_opto

puts "\n>>> Running synthesis (final optimization)..."
compile_fusion -to final_opto
save_block -as switch/final_opto

puts "\n>>> Generating reports..."
report_timing -max_paths 10 -nosplit > ${WORK_DIR}/timing_report.txt
report_timing -delay_type min -max_paths 10 -nosplit > ${WORK_DIR}/timing_hold_report.txt
report_qor -nosplit > ${WORK_DIR}/qor_report.txt
report_area -nosplit > ${WORK_DIR}/area_report.txt
report_area -hierarchy -nosplit > ${WORK_DIR}/area_hierarchy_report.txt
report_power -nosplit > ${WORK_DIR}/power_report.txt
report_design -nosplit > ${WORK_DIR}/design_report.txt
report_clocks -nosplit > ${WORK_DIR}/clock_report.txt
report_constraints -all_violators -nosplit > ${WORK_DIR}/constraint_violations.txt

puts "\n>>> Exporting netlist and SDF..."
write_verilog ${WORK_DIR}/switch_4port_netlist.v -hierarchy all
write_sdc -output ${WORK_DIR}/switch_synth.sdc
write_sdf -output ${WORK_DIR}/switch.sdf

puts ""
puts "=========================================="
puts " Synthesis Complete (NO CLOCK GATING)"
puts " Netlist: switch_4port_netlist.v"
puts " SDF:     switch.sdf"
puts " Reports: *_report.txt"
puts "=========================================="
puts ""

