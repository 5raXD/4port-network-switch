#lappend search_path scripts design_data
set_host_options -max_cores 4
set TECH_FILE     "/data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m.tf"
########################################################################
### Physical Library Settings
########################################################################
create_lib  -technology $TECH_FILE  -ref_libs { /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_hvt.ndm /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_lvt.ndm /data/synopsys/lib/saed32nm/ref/CLIBs/saed32_rvt.ndm }  fifo.dlib
open_lib fifo.dlib
report_ref_libs
read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmax.lv.tluplus -name Cmax
read_parasitic_tech -tlu /data/synopsys/lib/saed32nm/ref/tech/saed32nm_1p9m_Cmin.lv.tluplus -name Cmin
#
save_lib
analyze -format sverilog {fifo_core.sv write_ctrl.sv read_ctrl.sv top_fifo.sv}
elaborate top_fifo
set_top_module top_fifo
# save hir
set_app_options -name  compile.flow.autoungroup  -value false
#start_gui
save_block -as fifo/elaborate

# mcmm_setup:
# Remove all MCMM related info
remove_corners   -all
remove_modes     -all
remove_scenarios -all
# Create Corners
create_corner Fast
create_corner Slow
#
## Set parasitics parameters
set_parasitics_parameters -early_spec Cmin -late_spec  Cmin -corners {Fast}
set_parasitics_parameters -early_spec Cmax -late_spec  Cmax -corners {Slow}
#
## Create Mode
create_mode  FUNC
current_mode FUNC
#
## Create Scenarios
create_scenario -mode FUNC -corner Fast    -name FUNC_Fast
create_scenario -mode FUNC -corner Slow    -name FUNC_Slow
#

#sourse ConFiles/con431.con
current_scenario FUNC_Fast
source  /project/verif/users/majdf/ws/ex_vlsi_12/fifo.sdc
current_scenario FUNC_Slow
source  /project/verif/users/majdf/ws/ex_vlsi_12/fifo.sdc

set_auto_floorplan_constraints -core_utilization 0.7 -side_ratio {1 1} -core_offset 2
compile_fusion -to logic_opto
#create_placement
#legalize_placement
##Power
compile_fusion -to final_opto

save_block -as fifo/final_opto
report_timing

#set_attribute [get_layers {M1 M3 M5 M7 M9}]   routing_direction vertical
#set_attribute [get_layers {M2 M4 M6 M8 MRDL}] routing_direction horizontal

#source create_pg_network.tcl
#clock_opt
#route_opt
#save_block -as ALU/route_opt
