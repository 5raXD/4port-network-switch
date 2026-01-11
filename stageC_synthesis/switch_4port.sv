module switch_4port #(
  parameter NUM_PORTS = 4,
  parameter FIFO_DEPTH = 16
)(
  input logic clk,
  input logic rst_n,
  port_if port0,
  port_if port1,
  port_if port2,
  port_if port3
);

  // Arbiter states
  typedef enum logic [1:0] {ARB_IDLE, ARB_GRANT, ARB_COMPLETE} arb_state_e;
  arb_state_e arb_state, arb_next;
  
  logic [NUM_PORTS-1:0] request;
  logic [3:0] request_target [NUM_PORTS];
  logic [15:0] request_data [NUM_PORTS];
  logic [NUM_PORTS-1:0] grant;
  logic [NUM_PORTS-1:0] tx_done;
  logic [NUM_PORTS-1:0] internal_valid;
  logic [15:0] internal_data [NUM_PORTS];
  logic [1:0] rr_priority [NUM_PORTS];

  logic port_valid_in [NUM_PORTS];
  logic [3:0] port_source_in [NUM_PORTS];
  logic [3:0] port_target_in [NUM_PORTS];
  logic [7:0] port_data_in [NUM_PORTS];
  logic port_valid_out [NUM_PORTS];
  logic [3:0] port_source_out [NUM_PORTS];
  logic [3:0] port_target_out [NUM_PORTS];
  logic [7:0] port_data_out [NUM_PORTS];

  assign port_valid_in[0] = port0.valid_in; assign port_source_in[0] = port0.source_in;
  assign port_target_in[0] = port0.target_in; assign port_data_in[0] = port0.data_in;
  assign port0.valid_out = port_valid_out[0]; assign port0.source_out = port_source_out[0];
  assign port0.target_out = port_target_out[0]; assign port0.data_out = port_data_out[0];
  
  assign port_valid_in[1] = port1.valid_in; assign port_source_in[1] = port1.source_in;
  assign port_target_in[1] = port1.target_in; assign port_data_in[1] = port1.data_in;
  assign port1.valid_out = port_valid_out[1]; assign port1.source_out = port_source_out[1];
  assign port1.target_out = port_target_out[1]; assign port1.data_out = port_data_out[1];
  
  assign port_valid_in[2] = port2.valid_in; assign port_source_in[2] = port2.source_in;
  assign port_target_in[2] = port2.target_in; assign port_data_in[2] = port2.data_in;
  assign port2.valid_out = port_valid_out[2]; assign port2.source_out = port_source_out[2];
  assign port2.target_out = port_target_out[2]; assign port2.data_out = port_data_out[2];

  assign port_valid_in[3] = port3.valid_in; assign port_source_in[3] = port3.source_in;
  assign port_target_in[3] = port3.target_in; assign port_data_in[3] = port3.data_in;
  assign port3.valid_out = port_valid_out[3]; assign port3.source_out = port_source_out[3];
  assign port3.target_out = port_target_out[3]; assign port3.data_out = port_data_out[3];

  genvar g;
  generate
    for (g = 0; g < NUM_PORTS; g++) begin : gen_ports
      switch_port #(.FIFO_DEPTH(FIFO_DEPTH), .PORT_ID(g)) port_inst (
        .clk(clk), .rst_n(rst_n),
        .valid_in(port_valid_in[g]), .source_in(port_source_in[g]),
        .target_in(port_target_in[g]), .data_in(port_data_in[g]),
        .valid_out(port_valid_out[g]), .source_out(port_source_out[g]),
        .target_out(port_target_out[g]), .data_out(port_data_out[g]),
        .tx_done(tx_done[g]), .request(request[g]),
        .request_target(request_target[g]), .request_data(request_data[g]),
        .grant(grant[g]), .internal_valid(internal_valid[g]), .internal_data(internal_data[g])
      );
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) arb_state <= ARB_IDLE;
    else arb_state <= arb_next;

  always_comb begin
    arb_next = arb_state;
    case (arb_state)
      ARB_IDLE: if (|request) arb_next = ARB_GRANT;
      ARB_GRANT: arb_next = ARB_COMPLETE;
      ARB_COMPLETE: arb_next = ARB_IDLE;
    endcase
  end
  
  function automatic logic [1:0] rr_select(input logic [NUM_PORTS-1:0] candidates, input logic [1:0] last_priority);
    for (int offset = 1; offset <= NUM_PORTS; offset++) begin
      automatic int check = (last_priority + offset) % NUM_PORTS;
      if (candidates[check]) return check[1:0];
    end
    return 0;
  endfunction

  logic [NUM_PORTS-1:0] candidates [NUM_PORTS];
  logic [1:0] winner [NUM_PORTS];

  always_comb begin
    for (int out_port = 0; out_port < NUM_PORTS; out_port++) begin
      candidates[out_port] = '0;
      for (int in_port = 0; in_port < NUM_PORTS; in_port++)
        if (request[in_port] && request_target[in_port][out_port])
          candidates[out_port][in_port] = 1'b1;
      winner[out_port] = rr_select(candidates[out_port], rr_priority[out_port]);
    end
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      grant <= '0; internal_valid <= '0;
      for (int i = 0; i < NUM_PORTS; i++) begin internal_data[i] <= '0; rr_priority[i] <= '0; end
    end else case (arb_state)
      ARB_IDLE: begin
        grant <= '0; internal_valid <= '0;
      end
      ARB_GRANT: begin
        internal_valid <= '0;
        for (int out_port = 0; out_port < NUM_PORTS; out_port++) begin
          if (|candidates[out_port]) begin
            grant[winner[out_port]] <= 1'b1;
            internal_valid[out_port] <= 1'b1;
            internal_data[out_port] <= request_data[winner[out_port]];
            rr_priority[out_port] <= winner[out_port];
          end
        end
      end
      ARB_COMPLETE: begin
        grant <= '0; internal_valid <= '0;
      end
    endcase
  end

endmodule
