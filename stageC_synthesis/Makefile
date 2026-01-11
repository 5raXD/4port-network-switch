VIVADO_PATH = /home/ma5/xilinx/2025.2/Vivado/bin
XVLOG  = $(VIVADO_PATH)/xvlog
XELAB  = $(VIVADO_PATH)/xelab
XSIM   = $(VIVADO_PATH)/xsim

# Stage B RTL files (original with interface)
SRCS = packet_pkg.sv port_if.sv switch_port.sv switch_4port.sv coverage_module.sv switch_test.sv
TOP = switch_test

all: clean sim

sim: compile elaborate run

compile:
	@echo "=== Compiling with Vivado xvlog ==="
	$(XVLOG) -sv -i . $(SRCS)

elaborate:
	@echo "=== Elaborating ==="
	$(XELAB) $(TOP) -debug typical -s $(TOP)_sim

run:
	@echo "=== Running simulation ==="
	$(XSIM) $(TOP)_sim -runall

# VCS targets (for lab computers)
vcs-sim: vcs-comp vcs-run

vcs-comp:
	vcs -f build.cud -sverilog -kdb +vcs+fsdbon

vcs-run:
	./simv 2>&1 | tee sim.log

clean:
	@echo "=== Cleaning ==="
	@rm -rf xsim.dir xsim.jou xsim.log xelab.log xelab.pb xvlog.log xvlog.pb *.wdb .Xil
	@rm -rf simv* csrc* *.fsdb *.rc *.key verdi_config_file verdiLog *.conf sim.log
	@echo "Clean complete"

waveverdi:
	verdi -ssf novas.fsdb

help:
	@echo "Usage:"
	@echo "  make          - Clean, compile, elaborate, run (Vivado)"
	@echo "  make sim      - Compile, elaborate, run (Vivado)"
	@echo "  make vcs-sim  - Run with VCS (lab computers)"
	@echo "  make clean    - Remove all generated files"

.PHONY: all sim compile elaborate run clean help vcs-sim vcs-comp vcs-run
