# Makefile for 4-port Switch Verification
# Stage A & B Project

# Coverage flags for VCS
CM = line+cond+fsm+tgl+branch

# Source files
SRC = packet_pkg.sv port_if.sv switch_port.sv switch_4port.sv coverage_module.sv switch_test.sv

all: clean comp run

test: comp run

# Regular simulation (no coverage)
clean:
	\rm -rf simv* csrc* *.log *.fsdb *.rc *.key verdi_config_file verdiLog *.conf *.vdb urgReport coverage_report

comp:
	vcs -sverilog -full64 $(SRC)

run:
	qrun ./simv 2>&1 | tee log

waveverdi: 	
	verdi -ssf novas.fsdb

# Coverage simulation

# All in one: clean -> compile -> run -> view
cov_all: clean comp_cov run_cov view_cov

# Compile with coverage flags
comp_cov:
	vcs -sverilog -cm $(CM) -full64 $(SRC)

# Run sim with coverage
run_cov:
	qrun ./simv -cm $(CM) 2>&1 | tee log_cov
	@echo "Coverage database: simv.vdb"

# Open verdi to see coverage
view_cov:
	verdi -cov -covdir simv.vdb

# Make HTML report (optional)
report:
	urg -dir simv.vdb -report ./coverage_report -format both
	@echo "HTML Report: ./coverage_report/dashboard.html"

.PHONY: all test clean comp run waveverdi cov_all comp_cov run_cov view_cov report

