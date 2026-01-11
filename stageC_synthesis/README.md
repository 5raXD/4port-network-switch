# Stage C: Synthesis - 4-Port Network Switch

## What is Synthesis and How it Differs from Stages A & B

| Stage | Purpose | Tool | Input | Output |
|-------|---------|------|-------|--------|
| **A (RTL)** | Write hardware behavior | Editor | Specs | .sv files |
| **B (Verification)** | Test RTL correctness | VCS | RTL + TB | Sim logs, coverage |
| **C (Synthesis)** | Convert to physical gates | Fusion Compiler | RTL + SDC | Gate netlist, reports |

**Key Difference**: Stages A & B use *behavioral* code (what it does). Stage C produces *structural* code (how to build it with real gates).

---

## Directory Contents

### Original Stage B Files (RTL + Verification)
- `switch_4port.sv` - Top module with interface (for RTL sim)
- `switch_port.sv` - Port module (for RTL sim)  
- `packet_pkg.sv` - Package with classes + functions
- `port_if.sv` - Interface definition
- `switch_test.sv` - Testbench
- `*_checker.sv, agent.sv, driver.sv, etc.` - Verification components
- `build.cud` - File list for VCS

### New Stage C Files (Synthesis)
- `switch_4port_synth.sv` - **Synthesizable** top (flattened ports, no interface)
- `switch_port_synth.sv` - **Synthesizable** port (no $display, no classes)
- `switch.sdc` - Timing constraints (100MHz clock)
- `run_synthesis.tcl` - Synthesis script (no clock gating)
- `run_synthesis_clkgate.tcl` - Synthesis script (with clock gating)
- `switch_test_gate.sv` - Gate-level testbench

---

## How to Run

### 1. RTL Simulation (Stage B - verify code still works)

**From DVT Eclipse** (VCS is set up there):
- Import this project folder into DVT
- Use the build.cud file list
- Run simulation like Stage B

**From terminal (if VCS is in PATH)**:
```bash
cd /home/ma5/Desktop/uni/Design,\ Verification/proj_sunth_vlsi/stageA_B_new/stageC_synthesis
make test
```

### 2. Lint Check (Verilator - synthesizable code only)
```bash
verilator --lint-only -Wno-UNUSEDPARAM -Wno-UNUSEDSIGNAL switch_port_synth.sv switch_4port_synth.sv
```
✓ Passing means synthesizable RTL has no syntax errors

### 3. Synthesis (NO clock gating)
```bash
fc_shell
source run_synthesis.tcl
```
**Output**: `switch_4port_netlist.v`, `*_report.txt`

### 3. Synthesis (WITH clock gating)
```bash
fc_shell
source run_synthesis_clkgate.tcl
```
**Output**: `switch_4port_netlist_clkgate.v`, `*_report_clkgate.txt`, `clock_gating_report.txt`

### 4. Gate-Level Simulation
```bash
make gate_sim           # Without clock gating
make gate_sim_clkgate   # With clock gating
```

---

## Gate-Level Verification (What the Instructor Asked)

**Q**: What is gate-level simulation?
**A**: Run the Stage B verification on the netlist from synthesis to ensure:
1. Synthesis didn't introduce bugs
2. Behavior matches RTL exactly
3. All packets still route correctly

The `switch_test_gate.sv` runs the same tests as Stage B but on the synthesized netlist.

---

## Clock Gating Comparison

Clock gating stops the clock to unused registers → saves power.

| Metric | Without Clock Gating | With Clock Gating | Difference |
|--------|---------------------|-------------------|------------|
| Area (μm²) | ___ | ___ | ___% |
| Dynamic Power (mW) | ___ | ___ | ___% |
| Leakage Power (μW) | ___ | ___ | ___% |
| Setup Slack (ns) | ___ | ___ | ___ |
| Clock Gates | 0 | ___ | N/A |

*(Fill in after running both syntheses)*

---

## Maximum Frequency Calculation

From timing report:
```
Clock period = 10ns (100 MHz target)
Slack = X ns

Minimum period = 10ns - slack
Max frequency = 1 / minimum period
```

---

## Files Generated After Synthesis

```
switch_4port_netlist.v          # Gate-level netlist
switch_4port_netlist_clkgate.v  # Netlist with clock gating
timing_report.txt               # Critical paths, slack
area_report.txt                 # Cell count, area
power_report.txt                # Dynamic + leakage power
qor_report.txt                  # Quality of Results summary
clock_gating_report.txt         # Clock gating statistics
gate_sim.log                    # Gate-level simulation log
```

---

## Submission Checklist

- [ ] Run synthesis (no clock gating)
- [ ] Run synthesis (with clock gating)  
- [ ] Run gate-level simulation (both)
- [ ] Compare timing/area/power reports
- [ ] Fill in analysis tables above
- [ ] Verify gate-level sim matches RTL behavior
