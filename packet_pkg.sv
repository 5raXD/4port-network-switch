package packet_pkg;

  // Switch parameters
  parameter NUM_PORTS   = 4;
  parameter DATA_WIDTH  = 8;
  parameter FIFO_DEPTH  = 16;
  parameter PKT_WIDTH   = 16;  // source(4) + target(4) + data(8)
  
  // Port encodings (one-hot)
  parameter logic [3:0] PORT0 = 4'b0001;
  parameter logic [3:0] PORT1 = 4'b0010;
  parameter logic [3:0] PORT2 = 4'b0100;
  parameter logic [3:0] PORT3 = 4'b1000;
  parameter logic [3:0] BROADCAST = 4'b1111;

  // Functions to check if packet is illegal
  function automatic logic is_broadcast(input logic [3:0] tgt);
    return (tgt == 4'b1111);
  endfunction

  function automatic logic is_self_loop(input logic [3:0] src, input logic [3:0] tgt);
    if (is_broadcast(tgt)) return 1'b0;
    return |(src & tgt);
  endfunction
  
  function automatic logic is_no_target(input logic [3:0] tgt);
    return (tgt == 4'b0000);
  endfunction
  
  function automatic logic is_no_source(input logic [3:0] src);
    return (src == 4'b0000);
  endfunction
  
  function automatic logic is_multi_source(input logic [3:0] src);
    return (src != 4'b0000) && ((src & (src - 1)) != 4'b0000);
  endfunction

  function automatic logic is_invalid_source(input logic [3:0] src);
    return is_no_source(src) || is_multi_source(src);
  endfunction

  function automatic logic is_illegal_packet(input logic [3:0] src, input logic [3:0] tgt);
    return is_self_loop(src, tgt) || is_no_target(tgt) || is_invalid_source(src);
  endfunction
  
  function automatic string get_illegal_reason(input logic [3:0] src, input logic [3:0] tgt);
    if (is_self_loop(src, tgt))    return "SELF_LOOP: source bit in target (non-broadcast)";
    if (is_no_target(tgt))         return "NO_TARGET: target is zero";
    if (is_no_source(src))         return "NO_SOURCE: source is zero";
    if (is_multi_source(src))      return "MULTI_SOURCE: source not one-hot";
    return "VALID";
  endfunction


  `include "packet_data.sv"
  `include "component_base.sv"
  `include "sequencer.sv"
  `include "driver.sv"
  `include "monitor.sv"
  `include "agent.sv"
  `include "packet_vc.sv"
  `include "pkt_checker.sv"

endpackage
