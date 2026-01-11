puts ""
puts "Synthesis - 4-Port Network Switch"
puts "Clock Gating: ENABLED"
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

read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmax.lv.tluplus -name Cmax
read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmin.lv.tluplus -name Cmin
save_lib

puts "\nReading RTL files..."
analyze -format sverilog [list \
    ${WORK_DIR}/switch_port_synth.sv \
    ${WORK_DIR}/switch_4port_synth.sv \
]

elaborate $DESIGN_NAME
set_top_module $DESIGN_NAME
set_app_options -name compile.flow.autoungroup -value false
save_block -as switch_clkgate/elaborate

# ENABLE CLOCK GATING
puts "\nEnabling clock gating..."
set_app_options -name clock_opt.flow.enable_ccd -value true
set_app_options -name power.enable_clock_gating -value true
set_clock_gating_style -sequential_cell latch -minimum_bitwidth 4 -max_fanout 32
set_app_options -name compile.optimization.insert_clock_gating -value true

# MCMM setup
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

current_scenario FUNC_Fast
source ${WORK_DIR}/switch.sdc
current_scenario FUNC_Slow
source ${WORK_DIR}/switch.sdc

set_auto_floorplan_constraints -core_utilization 0.7 -side_ratio {1 1} -core_offset 2

puts "\nRunning synthesis with clock gating..."
compile_fusion -to logic_opto
save_block -as switch_clkgate/logic_opto

compile_fusion -to final_opto
save_block -as switch_clkgate/final_opto

# Reports
puts "\nGenerating reports..."
report_timing -max_paths 10 -nosplit > ${WORK_DIR}/timing_report_clkgate.txt
report_timing -delay_type min -max_paths 10 -nosplit > ${WORK_DIR}/timing_hold_report_clkgate.txt
report_qor -nosplit > ${WORK_DIR}/qor_report_clkgate.txt
report_area -nosplit > ${WORK_DIR}/area_report_clkgate.txt
report_area -hierarchy -nosplit > ${WORK_DIR}/area_hierarchy_report_clkgate.txt
report_power -nosplit > ${WORK_DIR}/power_report_clkgate.txt
report_clock_gating -nosplit > ${WORK_DIR}/clock_gating_report.txt
report_design -nosplit > ${WORK_DIR}/design_report_clkgate.txt

# Export netlist
puts "\nExporting netlist..."
write_verilog -hierarchy ${WORK_DIR}/switch_4port_netlist_clkgate.v
write_sdc ${WORK_DIR}/switch_synth_clkgate.sdc

puts "\n"
puts "Synthesis Complete (WITH CLOCK GATING)!"
puts "Netlist: switch_4port_netlist_clkgate.v"
puts "Clock gating report: clock_gating_report.txt"
puts ""