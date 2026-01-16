set_host_options -max_cores 4
set TECH_FILE "/data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m.tf"

create_lib -technology $TECH_FILE -ref_libs { \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_hvt.ndm \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_lvt.ndm \
    /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_rvt.ndm \
} switch.dlib

open_lib switch.dlib
report_ref_libs

read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmax.lv.tluplus -name Cmax
read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmin.lv.tluplus -name Cmin
save_lib

analyze -format sverilog {switch_port_synth.sv switch_4port_synth.sv}
elaborate switch_4port_synth
set_top_module switch_4port_synth
set_app_options -name compile.flow.autoungroup -value false
save_block -as switch/elaborate

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
source switch.sdc
current_scenario FUNC_Slow
source switch.sdc

set_auto_floorplan_constraints -core_utilization 0.7 -side_ratio {1 1} -core_offset 2
compile_fusion -to logic_opto
compile_fusion -to final_opto
save_block -as switch/final_opto


report_timing
report_area
report_power

start_gui

