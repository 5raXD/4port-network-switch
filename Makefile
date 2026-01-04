# Makefile for 4-port Switch Verification
# Stage A & B Project

# Coverage flags for VCS
CM = line+cond+fsm+tgl+branch

all:	clean comp run waveverdi

test:   comp run

# Regular simulation (no coverage)
clean:
	\rm -rf simv* csrc* *.log *.fsdb *.rc *.key verdi_config_file verdiLog *.conf *.vdb urgReport coverage_report

comp:
	vcs -f build.cud -sverilog -kdb +vcs+fsdbon

run:
	qrsh -V -cwd -b y -q normal ./simv 2>&1 | tee log

waveverdi: 	
	verdi -ssf novas.fsdb

# Coverage simulation - run these for Verdi coverage view

# All in one: clean -> compile -> run -> view
cov_all: clean comp_cov run_cov view_cov

# Compile with coverage flags (same build.cud, coverage_module is included)
comp_cov:
	vcs -f build.cud -sverilog -kdb +vcs+fsdbon -cm $(CM) -full64

# Run sim with coverage on
run_cov:
	qrsh -V -cwd -b y -q normal ./simv -cm $(CM) 2>&1 | tee log_cov
	@echo "Coverage database: simv.vdb"

# Open verdi to see coverage
view_cov:
	verdi -cov -covdir simv.vdb

# Make HTML report (optional)
report:
	urg -dir simv.vdb -report ./coverage_report -format both
	@echo "HTML Report: ./coverage_report/dashboard.html"

.PHONY: all test clean comp run waveverdi cov_all comp_cov run_cov view_cov report

