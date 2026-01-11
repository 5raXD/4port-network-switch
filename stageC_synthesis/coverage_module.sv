module coverage_module (
  input logic        clk,
  input logic        rst_n,
  // Packet sampling signals
  input logic        sample_valid,
  input logic [3:0]  pkt_source,
  input logic [3:0]  pkt_target,
  input logic [7:0]  pkt_data,
  input logic [1:0]  arb_state,
  input logic [1:0]  ingress_state_p0,
  input logic [1:0]  ingress_state_p1,
  input logic [1:0]  ingress_state_p2,
  input logic [1:0]  ingress_state_p3,
  input logic        egress_state_p0,
  input logic        egress_state_p1,
  input logic        egress_state_p2,
  input logic        egress_state_p3,
  input logic [3:0]  port_requests
);

  //signals for coverpoints
  logic [1:0] pkt_type;
  logic [1:0] src_port_idx;
  logic [1:0] dst_port_idx;
  int         num_targets;
  // Decode packet type and ports
  always_comb begin
    num_targets = $countones(pkt_target);
    if (pkt_target == 4'b1111)
      pkt_type = 2'b10;
    else if (num_targets > 1)
      pkt_type = 2'b01;
    else
      pkt_type = 2'b00;
    
    // Decode source port
    case (pkt_source)
      4'b0001: src_port_idx = 2'd0;
      4'b0010: src_port_idx = 2'd1;
      4'b0100: src_port_idx = 2'd2;
      4'b1000: src_port_idx = 2'd3;
      default: src_port_idx = 2'd0;
    endcase
    
    // Decode for single destination packets
    case (pkt_target)
      4'b0001: dst_port_idx = 2'd0;
      4'b0010: dst_port_idx = 2'd1;
      4'b0100: dst_port_idx = 2'd2;
      4'b1000: dst_port_idx = 2'd3;
      default: dst_port_idx = 2'd0;
    endcase
  end
  // Packet types
  covergroup cg_packet_types @(posedge clk iff (sample_valid && rst_n));
    cp_packet_type: coverpoint pkt_type {
      bins single_dest = {2'b00};
      bins multicast   = {2'b01};
      bins broadcast   = {2'b10};
    }
    
    cp_source_port: coverpoint src_port_idx {
      bins port0 = {0};
      bins port1 = {1};
      bins port2 = {2};
      bins port3 = {3};
    }
    
    cp_dest_port: coverpoint dst_port_idx iff (pkt_type == 2'b00) {
      bins port0 = {0};
      bins port1 = {1};
      bins port2 = {2};
      bins port3 = {3};
    }
    
    // Cross: source port × packet type
    cx_src_type: cross cp_source_port, cp_packet_type;
    
    // Cross: source port × destination port
    cx_src_dst: cross cp_source_port, cp_dest_port {
      // Ignore self-routing (illegal)
      ignore_bins self_route = binsof(cp_source_port) intersect {0} && binsof(cp_dest_port) intersect {0} ||
                               binsof(cp_source_port) intersect {1} && binsof(cp_dest_port) intersect {1} ||
                               binsof(cp_source_port) intersect {2} && binsof(cp_dest_port) intersect {2} ||
                               binsof(cp_source_port) intersect {3} && binsof(cp_dest_port) intersect {3};
    }
    
  endgroup

  //value ranges
  covergroup cg_data_values @(posedge clk iff (sample_valid && rst_n));
    
    cp_data: coverpoint pkt_data {
      bins zero     = {8'h00};
      bins low      = {[8'h01:8'h3F]};
      bins mid      = {[8'h40:8'hBF]};
      bins high     = {[8'hC0:8'hFE]};
      bins max      = {8'hFF};
    }
    
  endgroup

  //how many ports requesting at once
  covergroup cg_contention @(posedge clk iff rst_n);
    cp_num_requesters: coverpoint $countones(port_requests) {
      bins no_req     = {0};
      bins one_req    = {1};
      bins two_req    = {2};
      bins three_req  = {3};
      bins four_req   = {4};
    }
    
  endgroup

  //FSM states and transitions
  covergroup cg_arbiter_fsm @(posedge clk iff rst_n);
    cp_arb_state: coverpoint arb_state {
      bins idle     = {2'b00};
      bins grant    = {2'b01};
      bins complete = {2'b10};
    }
    
    cp_arb_transitions: coverpoint arb_state {
      bins idle_to_grant     = (2'b00 => 2'b01);
      bins grant_to_complete = (2'b01 => 2'b10);
      bins complete_to_idle  = (2'b10 => 2'b00);
      bins idle_to_idle      = (2'b00 => 2'b00);
    }
    
  endgroup

  covergroup cg_ingress_fsm @(posedge clk iff rst_n);
    cp_ingress_p0: coverpoint ingress_state_p0 {
      bins s_idle    = {2'b00};
      bins s_receive = {2'b01};
    }
    cp_ingress_p1: coverpoint ingress_state_p1 {
      bins s_idle    = {2'b00};
      bins s_receive = {2'b01};
    }
    cp_ingress_p2: coverpoint ingress_state_p2 {
      bins s_idle    = {2'b00};
      bins s_receive = {2'b01};
    }
    cp_ingress_p3: coverpoint ingress_state_p3 {
      bins s_idle    = {2'b00};
      bins s_receive = {2'b01};
    }
  endgroup

  covergroup cg_egress_fsm @(posedge clk iff rst_n);
    cp_egress_p0: coverpoint egress_state_p0 {
      bins e_idle   = {1'b0};
      bins e_output = {1'b1};
    }
    cp_egress_p1: coverpoint egress_state_p1 {
      bins e_idle   = {1'b0};
      bins e_output = {1'b1};
    }
    cp_egress_p2: coverpoint egress_state_p2 {
      bins e_idle   = {1'b0};
      bins e_output = {1'b1};
    }
    cp_egress_p3: coverpoint egress_state_p3 {
      bins e_idle   = {1'b0};
      bins e_output = {1'b1};
    }
  endgroup

  // Create covergroups
  cg_packet_types  cov_pkt_types;
  cg_data_values   cov_data;
  cg_contention    cov_contention;
  cg_arbiter_fsm   cov_arb_fsm;
  cg_ingress_fsm   cov_ingress;
  cg_egress_fsm    cov_egress;

  initial begin
    cov_pkt_types  = new();
    cov_data       = new();
    cov_contention = new();
    cov_arb_fsm    = new();
    cov_ingress    = new();
    cov_egress     = new();
  end

  // Print report at end
  final begin
    $display("");
    $display("COVERAGE REPORT");
    $display("Packet Types:   %0.2f%%", cov_pkt_types.get_coverage());
    $display("Data Values:    %0.2f%%", cov_data.get_coverage());
    $display("Contention:     %0.2f%%", cov_contention.get_coverage());
    $display("Arbiter FSM:    %0.2f%%", cov_arb_fsm.get_coverage());
    $display("Ingress FSM:    %0.2f%%", cov_ingress.get_coverage());
    $display("Egress FSM:     %0.2f%%", cov_egress.get_coverage());
    $display("");

  end

endmodule
