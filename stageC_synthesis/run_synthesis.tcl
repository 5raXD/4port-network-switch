# Synthesis Script for 4-Port Network Switch (NO clock gating)
# Tool: Synopsys Fusion Compiler
# Run: fc_shell then source run_synthesis.tcl

puts "=========================================="
puts "Synthesis - 4-Port Network Switch"
puts "Clock Gating: DISABLED"
puts "=========================================="

set_host_options -max_cores 4

set DESIGN_NAME "switch_4port_synth"
set WORK_DIR [pwd]

# Technology files
set TECH_FILE "/data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m.tf"

# Create design library
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

# Read RTL (synthesizable versions only)
puts "\nReading RTL files..."
analyze -format sverilog [list \
    ${WORK_DIR}/switch_port_synth.sv \
    ${WORK_DIR}/switch_4port_synth.sv \
]

elaborate $DESIGN_NAME
set_top_module $DESIGN_NAME
set_app_options -name compile.flow.autoungroup -value false
save_block -as switch/elaborate

# MCMM setup
puts "\nSetting up corners..."
remove_corners -all
remove_modes -all
remove_scenarios -all

create_corner Fast
create_corner Slow
set_parasitics_parameters -early_spec Cmin -late_spec Cmin -corners {Fast}
set_parasitics_parameters -early_spec Cmax -late_spec Cmax -corners {Slow}

create_mode FUNC
current_mode FUNC
create_scenario -mode FUNC -corner Fast -name FUNC_Fast
create_scenario -mode FUNC -corner Slow -name FUNC_Slow

# Apply constraints
puts "\nApplying timing constraints..."
current_scenario FUNC_Fast
source ${WORK_DIR}/switch.sdc
current_scenario FUNC_Slow
source ${WORK_DIR}/switch.sdc

# Floorplan
set_auto_floorplan_constraints -core_utilization 0.7 -side_ratio {1 1} -core_offset 2

# Synthesis
puts "\nRunning synthesis..."
compile_fusion -to logic_opto
save_block -as switch/logic_opto

compile_fusion -to final_opto
save_block -as switch/final_opto

# Reports
puts "\nGenerating reports..."
report_timing -max_paths 10 -nosplit > ${WORK_DIR}/timing_report.txt
report_timing -delay_type min -max_paths 10 -nosplit > ${WORK_DIR}/timing_hold_report.txt
report_qor -nosplit > ${WORK_DIR}/qor_report.txt
report_area -nosplit > ${WORK_DIR}/area_report.txt
report_area -hierarchy -nosplit > ${WORK_DIR}/area_hierarchy_report.txt
report_power -nosplit > ${WORK_DIR}/power_report.txt
report_design -nosplit > ${WORK_DIR}/design_report.txt
report_clocks -nosplit > ${WORK_DIR}/clock_report.txt
report_constraints -all_violators -nosplit > ${WORK_DIR}/constraint_violations.txt

# Export netlist
puts "\nExporting netlist..."
write_verilog -hierarchy ${WORK_DIR}/switch_4port_netlist.v
write_sdc ${WORK_DIR}/switch_synth.sdc

puts "\n=========================================="
puts "Synthesis Complete!"
puts "Netlist: switch_4port_netlist.v"
puts "Reports: *_report.txt"
puts "=========================================="
