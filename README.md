# 4-Port Network Switch - Complete Documentation

This README explains EVERYTHING about this project - every file, every design decision, every concept, and how to run it.

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Stage A - RTL Design](#stage-a---rtl-design)
3. [Stage B - Verification](#stage-b---verification)
4. [File-by-File Breakdown](#file-by-file-breakdown)
5. [How to Run](#how-to-run)
6. [Coverage Explanation](#coverage-explanation)
7. [Important Lessons Learned](#important-lessons-learned)

---

## Project Overview

### What is this?
A 4-port network switch that routes packets between ports. Think of it like a mini network router - packets come in on one port and get sent to one or more destination ports.


- **source**: One-hot encoded source port (which port sent this packet)
  - Port 0 = 4'b0001
  - Port 1 = 4'b0010
  - Port 2 = 4'b0100
  - Port 3 = 4'b1000

- **target**: One-hot encoded destination(s) - can be multiple bits set!
  - Single destination: 4'b0001 (only port 0)
  - Multicast: 4'b0110 (ports 1 and 2)
  - Broadcast: 4'b1111 (all 4 ports)

- **data**: 8-bit payload (the actual data being sent)

### Three Packet Types
1. **Single Destination**: Target has exactly 1 bit set (goes to 1 port)
2. **Multicast**: Target has 2-3 bits set (goes to multiple ports)
3. **Broadcast**: Target = 4'b1111 (goes to ALL ports, including sender)

### Illegal Packets (get dropped)
The switch drops packets that are:
- **Self-loop**: source bit is in target (sending to yourself) - UNLESS broadcast
- **No target**: target = 4'b0000
- **No source**: source = 4'b0000  
- **Multi-source**: source has more than 1 bit set (impossible - packet can only come from 1 port)

---

## Stage A - RTL Design

### Architecture Overview

```
                    +------------------+
     port0 ------>  |                  | ------> port0
     port1 ------>  |   switch_4port   | ------> port1
     port2 ------>  |   (top level)    | ------> port2
     port3 ------>  |                  | ------> port3
                    +------------------+
                           |
           +---------------+---------------+
           |               |               |
      +---------+    +---------+    +---------+
      | switch  |    | switch  |    | ARBITER |
      | _port 0 |    | _port 1 |    | (round  |
      |   ...   |    |   ...   |    |  robin) |
      +---------+    +---------+    +---------+
```

### switch_port.sv - Single Port Module

Each port has the same structure:

```
              INGRESS                 FIFO                  EGRESS
            +----------+         +----------+          +----------+
valid_in -->| INGRESS  |-------->|   FIFO   |--------->| EGRESS   |---> valid_out
source_in-->|   FSM    | pack    |  (depth  | request  |   FSM    |---> source_out
target_in-->| (receive |-------->|   =16)   |--------->| (output  |---> target_out
data_in --->|  packet) |         +----------+  grant   |  packet) |---> data_out
            +----------+              |                +----------+
                                      |                     ^
                                      v                     |
                               +-------------+              |
                               |  ARBITER    |--------------+
                               | (in switch_ |  internal_valid
                               |   4port)    |  internal_data
                               +-------------+
```

#### Ingress FSM (2 states)
```
S_IDLE -----(valid_in && !full && !illegal)-----> S_RECEIVE
  ^                                                   |
  |                                                   |
  +<-------------(write to FIFO)----------------------+
```

- **S_IDLE**: Waiting for packet. When valid_in goes high, capture the packet fields.
- **S_RECEIVE**: Write the captured packet to FIFO, go back to IDLE.

Why 2 states? Because we need 1 cycle to capture the data, 1 cycle to write to FIFO. This prevents glitches.

#### FIFO
- Depth = 16 (can hold 16 packets)
- Uses `wr_ptr` (write pointer) and `rd_ptr` (read pointer)
- `count` tracks how many packets are in FIFO
- `fifo_full` = (count == 16), `fifo_empty` = (count == 0)

FIFO operations:
- **Write**: When `fifo_wr_en` is high, write data to `fifo_mem[wr_ptr]` and increment `wr_ptr`
- **Read**: When `grant` is high (arbiter grants us), increment `rd_ptr`

The FIFO always outputs `fifo_mem[rd_ptr]` on `request_data` - this is what we're asking to send.

#### Egress FSM (2 states)
```
E_IDLE -----(internal_valid)-----> E_OUTPUT
  ^                                    |
  |                                    |
  +<---------(tx_done pulse)-----------+
```

- **E_IDLE**: Waiting for arbiter to give us data. When `internal_valid` goes high, latch `internal_data` to output.
- **E_OUTPUT**: Data is on output for 1 cycle, then set `tx_done` and go back to IDLE.

#### Important Signals
```systemverilog
// Arbiter interface (from port to arbiter)
output logic        request;         // "I have data to send!"
output logic [3:0]  request_target;  // "I want to send to these ports"
output logic [15:0] request_data;    // "Here's my packet"

// Arbiter interface (from arbiter to port)
input  logic        grant;           // "OK, I'm taking your packet from FIFO"
input  logic        internal_valid;  // "Here's a packet FOR you to output"
input  logic [15:0] internal_data;   // "This is the packet data"
```

### switch_4port.sv - Top Level with Arbiter

#### Port Instantiation
Uses `generate` block to create 4 identical `switch_port` instances:
```systemverilog
genvar g;
generate
  for (g = 0; g < NUM_PORTS; g++) begin : gen_ports
    switch_port #(.FIFO_DEPTH(FIFO_DEPTH), .PORT_ID(g)) port_inst (
      // ... signals ...
    );
  end
endgenerate
```

Why `generate`? So we don't have to copy-paste the same code 4 times. Each port is identical except for `PORT_ID`.

#### Arbiter FSM (3 states)

```
ARB_IDLE -----(any request)-----> ARB_GRANT
    ^                                 |
    |                                 v
    +<------ARB_COMPLETE<-------------+
```

- **ARB_IDLE**: Check if any port has a request
- **ARB_GRANT**: Decide who wins (round-robin), set `grant` and `internal_valid`
- **ARB_COMPLETE**: Clear signals, go back to IDLE

#### Round-Robin Arbitration

The key function:
```systemverilog
function automatic logic [1:0] rr_select(input logic [NUM_PORTS-1:0] candidates, input logic [1:0] last_priority);
  for (int offset = 1; offset <= NUM_PORTS; offset++) begin
    automatic int check = (last_priority + offset) % NUM_PORTS;
    if (candidates[check]) return check[1:0];
  end
  return 0;
endfunction
```

How it works:
1. Start from `last_priority + 1` (the port AFTER the last winner)
2. Check each port in order: if it's requesting, it wins
3. This ensures fairness - nobody gets starved

Example:
- Last winner was port 1 (`last_priority = 1`)
- Ports 0 and 2 are requesting
- Check order: 2, 3, 0, 1
- Port 2 wins (first requesting port after port 1)

Each output port has its own `rr_priority` register because multiple output ports can receive packets in the same cycle (no contention for DIFFERENT outputs).

#### Contention Handling

```systemverilog
// For each output port, find which input ports want to send to it
always_comb begin
  for (int out_port = 0; out_port < NUM_PORTS; out_port++) begin
    candidates[out_port] = '0;
    for (int in_port = 0; in_port < NUM_PORTS; in_port++)
      if (request[in_port] && request_target[in_port][out_port])
        candidates[out_port][in_port] = 1'b1;
    winner[out_port] = rr_select(candidates[out_port], rr_priority[out_port]);
  end
end
```

Example scenario:
- Port 0 wants to send to Port 2 (target = 4'b0100)
- Port 1 wants to send to Port 2 (target = 4'b0100)
- `candidates[2]` = 4'b0011 (both ports 0 and 1 are requesting output port 2)
- `rr_select` picks one winner based on priority

### port_if.sv - Interface

Why use an interface? It bundles all the signals together and makes connections cleaner.

```systemverilog
interface port_if (input bit clk, input bit rst_n);
  // Input signals (TB -> DUT)
  logic valid_in, source_in, target_in, data_in;
  
  // Output signals (DUT -> TB)
  logic valid_out, source_out, target_out, data_out;
  
  // BFM task - testbench calls this to send a packet
  task drive_packet(input packet p);
    @(posedge clk);
    valid_in <= 1; source_in <= p.source; target_in <= p.target; data_in <= p.data;
    @(posedge clk);
    valid_in <= 0;  // valid is only high for 1 cycle
  endtask
endinterface
```

BFM = Bus Functional Model. It's a task that knows HOW to drive the interface correctly.

---

## Stage B - Verification

### Verification Architecture

```
+------------------------------------------------------------------+
|                         switch_test.sv (testbench)               |
|                                                                  |
|  +------------+   +------------+   +------------+   +----------+ |
|  | packet_vc  |   | packet_vc  |   | packet_vc  |   | packet_  | |
|  |   [0]      |   |   [1]      |   |   [2]      |   |   vc[3]  | |
|  +-----+------+   +-----+------+   +-----+------+   +----+-----+ |
|        |               |               |                |        |
|        v               v               v                v        |
|  +---------+     +---------+     +---------+     +---------+    |
|  | port_if |     | port_if |     | port_if |     | port_if |    |
|  +---------+     +---------+     +---------+     +---------+    |
+-----|---------------|---------------|---------------|------------+
      |               |               |               |
      v               v               v               v
+------------------------------------------------------------------+
|                         switch_4port (DUT)                       |
+------------------------------------------------------------------+
      |               |               |               |
      +-------+-------+-------+-------+-------+-------+
              |                       |
              v                       v
        +------------+        +------------------+
        | pkt_checker|        | coverage_module  |
        | (scoreboard)|       | (func coverage)  |
        +------------+        +------------------+
```

### Component Hierarchy

```
packet_vc (Verification Component)
    └── agent
          ├── sequencer  (generates random packets)
          ├── driver     (sends packets to DUT)
          └── monitor    (captures DUT output)
```

This is a simplified UVM-style architecture. Each class has a single responsibility.

### packet_pkg.sv - Package

The package contains:
1. **Parameters**: NUM_PORTS, DATA_WIDTH, FIFO_DEPTH, port encodings
2. **Helper functions**: `is_illegal_packet()`, `is_self_loop()`, etc.
3. **Include statements**: All the verification class files

```systemverilog
package packet_pkg;
  parameter logic [3:0] PORT0 = 4'b0001;  // one-hot encodings
  parameter logic [3:0] PORT1 = 4'b0010;
  parameter logic [3:0] PORT2 = 4'b0100;
  parameter logic [3:0] PORT3 = 4'b1000;
  parameter logic [3:0] BROADCAST = 4'b1111;
  
  // Include all verification classes
  `include "packet_data.sv"
  `include "component_base.sv"
  // ... etc
endpackage
```

Why a package? So we can `import packet_pkg::*` anywhere and get access to all the classes and constants.

### component_base.sv - Base Class

```systemverilog
class component_base;
  string name;
  component_base parent;
  
  function string pathname();  // returns "parent.child.grandchild"
    if (parent == null) return name;
    else return {parent.pathname(), ".", name};
  endfunction
endclass
```

All verification components extend this. It provides:
- Hierarchical naming (for debug prints)
- Parent-child relationships (like UVM)

### packet_data.sv - Packet Classes

#### Base packet class
```systemverilog
class packet;
  rand logic [3:0] source;
  rand logic [3:0] target;
  rand logic [7:0] data;
  
  // Constraints ensure only LEGAL packets are generated
  constraint valid_source { source inside {4'b0001, 4'b0010, 4'b0100, 4'b1000}; }
  constraint valid_target { target != 4'b0000; }
  constraint no_source_in_target { (target & source) == 4'b0000 || target == 4'b1111; }
endclass
```

`rand` keyword means these fields can be randomized with `p.randomize()`.

**Constraints** are rules the randomizer must follow:
- `valid_source`: source must be one-hot (only 1 bit set)
- `valid_target`: target can't be zero
- `no_source_in_target`: can't send to yourself (except broadcast)

#### Specialized packet classes
```systemverilog
class single_packet extends packet;
  constraint single_target { target inside {4'b0001, 4'b0010, 4'b0100, 4'b1000}; }
endclass

class multicast_packet extends packet;
  constraint multi_target { target inside {4'b0011, 4'b0101, ...}; } // 2-3 bits set
endclass

class broadcast_packet extends packet;
  constraint bcast_target { target == 4'b1111; }
endclass
```

Inheritance lets us reuse constraints and add more specific ones.

### sequencer.sv - Packet Generator

```systemverilog
class sequencer extends component_base;
  int port_idx;  // which port this sequencer is for
  
  function packet get_next_packet();
    int pkt_type = $urandom_range(0, 2);  // random type
    case (pkt_type)
      0: begin single_packet sp = new(); sp.randomize(); return sp; end
      1: begin multicast_packet mp = new(); mp.randomize(); return mp; end
      2: begin broadcast_packet bp = new(); bp.randomize(); return bp; end
    endcase
  endfunction
endclass
```

The sequencer generates stimulus. It can create random packets or specific types for directed tests.

### driver.sv - Packet Sender

```systemverilog
class driver extends component_base;
  virtual port_if vif;  // handle to the interface
  
  task drive(packet p);
    vif.drive_packet(p);  // call the BFM task
  endtask
endclass
```

`virtual interface` is how classes can access module interfaces. The testbench assigns the actual interface to this handle.

### monitor.sv - Output Watcher

```systemverilog
class monitor extends component_base;
  virtual port_if vif;
  mailbox #(packet) rx_mbx;  // queue to send packets to checker
  
  task run();
    forever begin
      @(posedge vif.clk);
      if (vif.valid_out) begin
        // Capture packet and send to checker via mailbox
        packet p = new();
        p.source = vif.source_out;
        p.target = vif.target_out;
        p.data = vif.data_out;
        rx_mbx.put(p);
      end
    end
  endtask
endclass
```

Mailbox is SystemVerilog's built-in message queue for passing objects between processes.

### agent.sv - Groups Seq/Drv/Mon

```systemverilog
class agent extends component_base;
  sequencer seq;
  driver drv;
  monitor mon;
  
  function new(string n, component_base p = null);
    super.new(n, p);
    seq = new("sequencer", this);  // this agent is the parent
    drv = new("driver", this);
    mon = new("monitor", this);
  endfunction
endclass
```

The agent is just a container that creates and owns the sequencer, driver, and monitor.

### packet_vc.sv - Verification Component

```systemverilog
class packet_vc extends component_base;
  agent agt;
  
  function void configure(virtual port_if vif, int port_idx);
    agt.set_interface(vif);
    agt.set_port(port_idx);
  endfunction
  
  task run(int num_packets);
    for (int i = 0; i < num_packets; i++) begin
      packet p = agt.seq.get_next_packet();
      agt.drv.drive(p);
      repeat(5) @(posedge vif.clk);  // wait between packets
    end
  endtask
endclass
```

The VC is the highest-level verification component. One VC per port.

### pkt_checker.sv - Scoreboard

```systemverilog
class pkt_checker extends component_base;
  packet expected_q[4][$];  // 4 queues, one per port
  
  // Called when driver sends packet
  function void add_expected(packet p);
    for (int port = 0; port < 4; port++)
      if (p.target[port])  // if this port is a target
        expected_q[port].push_back(p.copy());
  endfunction
  
  // Called when monitor sees output
  function void check_received(int port_idx, packet p);
    // Search expected queue for matching packet
    for (int i = 0; i < expected_q[port_idx].size(); i++) begin
      if (match(expected_q[port_idx][i], p)) begin
        expected_q[port_idx].delete(i);  // found it!
        return;
      end
    end
    // If we get here, packet was unexpected - ERROR!
  endfunction
endclass
```

The scoreboard predicts what outputs should appear and verifies they actually do.

**Key insight**: For multicast/broadcast, ONE input packet creates MULTIPLE expected outputs (one per target port).

---

## File-by-File Breakdown

### Stage A (RTL) Files

| File | Purpose | Key Concepts |
|------|---------|--------------|
| `packet_pkg.sv` | Package with constants, functions, and includes | Packages, one-hot encoding, helper functions |
| `port_if.sv` | Interface connecting TB to DUT | Interfaces, BFM tasks, modports |
| `switch_port.sv` | Single port with FIFO | FSMs, FIFO implementation, pipelining |
| `switch_4port.sv` | Top level with arbiter | Generate blocks, round-robin arbitration, contention handling |

### Stage B (Verification) Files

| File | Purpose | Key Concepts |
|------|---------|--------------|
| `packet_data.sv` | Packet classes with constraints | Classes, randomization, constraints, inheritance |
| `component_base.sv` | Base class for all components | OOP, hierarchical naming |
| `sequencer.sv` | Generates random packets | Factory pattern, randomization |
| `driver.sv` | Sends packets to DUT | Virtual interfaces, tasks |
| `monitor.sv` | Captures DUT output | Forever loops, mailboxes |
| `agent.sv` | Groups seq/drv/mon | Composition, encapsulation |
| `packet_vc.sv` | High-level verification component | Abstraction layers |
| `pkt_checker.sv` | Scoreboard - verifies correctness | Queues, expected vs actual comparison |
| `coverage_module.sv` | Functional coverage | Covergroups, coverpoints, crosses |
| `switch_test.sv` | Main testbench | Test scenarios, stimulus, checking |

### Build Files

| File | Purpose |
|------|---------|
| `build.cud` | File list for VCS |
| `Makefile` | Build and run commands |

---

## How to Run

### Prerequisites
- VCS simulator (Synopsys)
- Verdi waveform viewer (Synopsys)

### Directory Structure After Build
```
stageA_B_optimized/
├── simv           # compiled executable
├── simv.vdb/      # coverage database
├── novas.fsdb     # waveform database
├── log            # simulation output
└── ...
```

### Running WITHOUT Coverage

This is faster, use for debugging:

```bash
# Clean everything and rebuild
make all

# Or step by step:
make clean       # remove old files
make comp        # compile (vcs -f build.cud -sverilog ...)
make run         # run simulation (./simv)
make waveverdi   # open waveform viewer
```

What happens:
1. VCS reads `build.cud` which lists all source files
2. VCS compiles everything into `simv` executable
3. `./simv` runs the simulation
4. Waveforms are saved to `novas.fsdb`

### Running WITH Coverage

This collects coverage data:

```bash
# All in one command
make cov_all

# Or step by step:
make clean
make comp_cov    # compile with coverage flags
make run_cov     # run with coverage collection
make view_cov    # open Verdi coverage viewer
```

What the coverage flags do:
```bash
vcs -cm line+cond+fsm+tgl+branch -full64
```
- `-cm line`: Line coverage (which lines executed)
- `-cm cond`: Condition coverage (boolean expressions)
- `-cm fsm`: FSM coverage (state machine states/transitions)
- `-cm tgl`: Toggle coverage (signal 0->1 and 1->0)
- `-cm branch`: Branch coverage (if/else branches)
- `-full64`: 64-bit mode

### Make Coverage Report (HTML)

```bash
make report
# Opens coverage_report/dashboard.html
```

### Manual Commands (if make doesn't work)

```bash
# Compile
vcs -f build.cud -sverilog -kdb +vcs+fsdbon

# Run
./simv

# Compile with coverage
vcs -f build.cud -sverilog -kdb +vcs+fsdbon -cm line+cond+fsm+tgl+branch -full64

# Run with coverage
./simv -cm line+cond+fsm+tgl+branch

# View coverage
verdi -cov -covdir simv.vdb

# View waveforms
verdi -ssf novas.fsdb
```

---

## Coverage Explanation

### Why Coverage Matters
Coverage tells us HOW WELL our tests exercised the design. High coverage = confidence that the design works.

### Code Coverage (automatic)
VCS collects these automatically with `-cm` flags:

1. **Line Coverage**: Did we execute every line of RTL code?
2. **Branch Coverage**: Did we take both paths of every if/else?
3. **Condition Coverage**: Did each boolean term evaluate to both true and false?
4. **FSM Coverage**: Did we visit every state and every transition?
5. **Toggle Coverage**: Did every signal flip 0→1 and 1→0?

### Functional Coverage (manual)

We define what scenarios we WANT to test in `coverage_module.sv`:

```systemverilog
// Covergroup for packet types
covergroup cg_packet_types @(posedge clk iff sample_valid);
  cp_packet_type: coverpoint pkt_type {
    bins single_dest = {2'b00};
    bins multicast   = {2'b01};
    bins broadcast   = {2'b10};
  }
  
  cp_source_port: coverpoint src_port_idx {
    bins port0 = {0}; bins port1 = {1}; bins port2 = {2}; bins port3 = {3};
  }
  
  // Cross coverage: did we test all combinations?
  cx_src_type: cross cp_source_port, cp_packet_type;
endgroup
```

**Coverpoints**: Individual things to cover (e.g., packet types)
**Bins**: Specific values to hit (e.g., single_dest, multicast, broadcast)
**Cross**: Combinations of coverpoints (e.g., every source × every type)

### Our Covergroups

1. **cg_packet_types**: Packet types, source ports, destination ports, and their crosses
2. **cg_data_values**: Edge case data values (0x00, 0xFF, and ranges)
3. **cg_contention**: How many ports requesting simultaneously (0, 1, 2, 3, 4)
4. **cg_arbiter_fsm**: Arbiter states and transitions
5. **cg_ingress_fsm**: Ingress FSM states for all 4 ports
6. **cg_egress_fsm**: Egress FSM states for all 4 ports

### CRITICAL: Why Module-Based Coverage

**THIS WAS A HUGE GOTCHA!**

VCS `-cm` flags ONLY work with module-level covergroups, NOT class-based ones.

❌ **WRONG** (doesn't work with VCS -cm):
```systemverilog
class func_coverage;
  covergroup cg @(posedge clk);
    // ...
  endgroup
endclass
```

✅ **CORRECT** (works with VCS -cm):
```systemverilog
module coverage_module (...);
  covergroup cg @(posedge clk);
    // ...
  endgroup
  
  cg cov_inst = new();  // instantiate in module
endmodule
```

I spent HOURS debugging why coverage was 0% in Verdi. The simulation was running fine, but coverage wasn't being collected. The answer: VCS coverage collection only hooks into module-level covergroups.

---

## Important Lessons Learned

### 1. One-Hot Encoding
Using one-hot for source/target makes the logic simpler:
- No decoder needed
- Easy to check "is this port a target?" with `target[port_idx]`
- Multicast/broadcast is natural: just set multiple bits

### 2. Arbiter Design
Round-robin is fair but adds latency. Alternative: priority-based (faster but can starve lower-priority ports).

### 3. FIFO Sizing
FIFO depth = 16 is enough for normal traffic. For burst traffic, might need more.

### 4. Testbench Architecture
Separating concerns (sequencer generates, driver sends, monitor watches, checker verifies) makes the TB maintainable and reusable.

### 5. Coverage-Driven Verification
Write coverage first, then write tests to hit coverage. This ensures you're testing what matters.

### 6. VCS Coverage Gotcha
Module-level covergroups only! Class-based coverage doesn't work with VCS `-cm` flags.

### 7. Illegal Packet Handling
Always think about what happens with bad inputs. Our switch drops illegal packets with a warning message.

---

## Test Scenarios in switch_test.sv

| Test | What It Does | Why |
|------|--------------|-----|
| Test 1 | All 12 src→dst combinations | Basic functionality |
| Test 2 | Multicast from each port | Multi-destination routing |
| Test 3 | Broadcast from each port | All-port delivery |
| Test 4 | 2-way contention (port0 & port1 → port2) | Arbiter round-robin |
| Test 5 | All 4 ports simultaneously (no contention) | Parallel operation |
| Test 6 | 16 random packets | Random stimulus |
| Test 7 | Edge data values (0x00, 0xFF) | Boundary testing |
| Test 8 | 3-way contention | Heavy contention |

---

## Debugging Tips

### If simulation hangs:
- Check FSM states in waveform
- Look for missing `@(posedge clk)` in tasks
- Check if FIFO is full (packets dropped)

### If packets are lost:
- Check the checker report at end of simulation
- Look at `expected_q` sizes - packets still in queue weren't received
- Check illegal packet warnings in log

### If coverage is 0%:
- Make sure you compiled with `-cm` flags
- Make sure you ran with `-cm` flags
- Make sure covergroups are in a MODULE, not a class

### Useful Verdi commands:
- `nWave` → waveform viewer
- `nCov` → coverage viewer
- Click on FSM to see state diagram
- Use cursors to measure timing

---

## Quick Reference

### Compile and run (no coverage)
```bash
make all
```

### Compile and run (with coverage)
```bash
make cov_all
```

### View waveforms
```bash
make waveverdi
```

### View coverage
```bash
make view_cov
```

### Generate HTML report
```bash
make report
```

---

That's everything! Good luck with the project! 🚀


