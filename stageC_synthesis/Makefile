all:	clean comp run waveverdi

test:   comp run

clean:
	\rm -rf simv* csrc* *.log *.fsdb *.rc *.key verdi_config_file verdiLog *.conf

comp:
	vcs -f build.cud -sverilog -kdb +vcs+fsdbon 2>&1 | tee comp.log

run:
	./simv 2>&1 | tee run.log

waveverdi:
	verdi -ssf novas.fsdb

coverage:
	verdi -cov -covdir simv.vdb

# Gate-level sim (no clock gating)
gate-comp:
	vcs -f build.cud -sverilog -kdb +vcs+fsdbon -sdf typ:switch_test_gate.dut:switch.sdf -o simv_gate 2>&1 | tee gate_comp.log

gate-run:
	./simv_gate 2>&1 | tee gate_run.log

gate-sim: gate-comp gate-run

# Gate-level sim (with clock gating)
gate-clkgate-comp:
	vcs -f build.cud -sverilog -kdb +vcs+fsdbon -sdf typ:switch_test_gate.dut:switch_clkgate.sdf -o simv_gate_clkgate 2>&1 | tee gate_clkgate_comp.log

gate-clkgate-run:
	./simv_gate_clkgate 2>&1 | tee gate_clkgate_run.log

gate-clkgate-sim: gate-clkgate-comp gate-clkgate-run

waveverdi-gate:
	verdi -ssf novas.fsdb

