module switch_4port_synth #(
  parameter NUM_PORTS = 4,
  parameter FIFO_DEPTH = 16
)(
  input logic clk,
  input logic rst_n,
  
  // Port 0
  input  logic        port0_valid_in,
  input  logic [3:0]  port0_source_in,
  input  logic [3:0]  port0_target_in,
  input  logic [7:0]  port0_data_in,
  output logic        port0_valid_out,
  output logic [3:0]  port0_source_out,
  output logic [3:0]  port0_target_out,
  output logic [7:0]  port0_data_out,
  
  // Port 1
  input  logic        port1_valid_in,
  input  logic [3:0]  port1_source_in,
  input  logic [3:0]  port1_target_in,
  input  logic [7:0]  port1_data_in,
  output logic        port1_valid_out,
  output logic [3:0]  port1_source_out,
  output logic [3:0]  port1_target_out,
  output logic [7:0]  port1_data_out,
  
  // Port 2
  input  logic        port2_valid_in,
  input  logic [3:0]  port2_source_in,
  input  logic [3:0]  port2_target_in,
  input  logic [7:0]  port2_data_in,
  output logic        port2_valid_out,
  output logic [3:0]  port2_source_out,
  output logic [3:0]  port2_target_out,
  output logic [7:0]  port2_data_out,
  
  // Port 3
  input  logic        port3_valid_in,
  input  logic [3:0]  port3_source_in,
  input  logic [3:0]  port3_target_in,
  input  logic [7:0]  port3_data_in,
  output logic        port3_valid_out,
  output logic [3:0]  port3_source_out,
  output logic [3:0]  port3_target_out,
  output logic [7:0]  port3_data_out
);

  // Arbiter FSM states
  typedef enum logic [1:0] {ARB_IDLE, ARB_GRANT, ARB_COMPLETE} arb_state_e;
  arb_state_e arb_state, arb_next;
  
  logic [NUM_PORTS-1:0] request;
  logic [3:0] request_target [NUM_PORTS];
  logic [15:0] request_data [NUM_PORTS];
  logic [NUM_PORTS-1:0] grant;
  logic [NUM_PORTS-1:0] tx_done;  // Output from ports, may be used for debug
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

  // Port 0 mapping
  assign port_valid_in[0] = port0_valid_in;
  assign port_source_in[0] = port0_source_in;
  assign port_target_in[0] = port0_target_in;
  assign port_data_in[0] = port0_data_in;
  assign port0_valid_out = port_valid_out[0];
  assign port0_source_out = port_source_out[0];
  assign port0_target_out = port_target_out[0];
  assign port0_data_out = port_data_out[0];
  
  // Port 1 mapping
  assign port_valid_in[1] = port1_valid_in;
  assign port_source_in[1] = port1_source_in;
  assign port_target_in[1] = port1_target_in;
  assign port_data_in[1] = port1_data_in;
  assign port1_valid_out = port_valid_out[1];
  assign port1_source_out = port_source_out[1];
  assign port1_target_out = port_target_out[1];
  assign port1_data_out = port_data_out[1];
  
  // Port 2 mapping
  assign port_valid_in[2] = port2_valid_in;
  assign port_source_in[2] = port2_source_in;
  assign port_target_in[2] = port2_target_in;
  assign port_data_in[2] = port2_data_in;
  assign port2_valid_out = port_valid_out[2];
  assign port2_source_out = port_source_out[2];
  assign port2_target_out = port_target_out[2];
  assign port2_data_out = port_data_out[2];

  // Port 3 mapping
  assign port_valid_in[3] = port3_valid_in;
  assign port_source_in[3] = port3_source_in;
  assign port_target_in[3] = port3_target_in;
  assign port_data_in[3] = port3_data_in;
  assign port3_valid_out = port_valid_out[3];
  assign port3_source_out = port_source_out[3];
  assign port3_target_out = port_target_out[3];
  assign port3_data_out = port_data_out[3];

  // Instantiate 4 switch_port modules
  genvar g;
  generate
    for (g = 0; g < NUM_PORTS; g++) begin : gen_ports
      switch_port_synth #(.FIFO_DEPTH(FIFO_DEPTH), .PORT_ID(g)) port_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(port_valid_in[g]),
        .source_in(port_source_in[g]),
        .target_in(port_target_in[g]),
        .data_in(port_data_in[g]),
        .valid_out(port_valid_out[g]),
        .source_out(port_source_out[g]),
        .target_out(port_target_out[g]),
        .data_out(port_data_out[g]),
        .tx_done(tx_done[g]),
        .request(request[g]),
        .request_target(request_target[g]),
        .request_data(request_data[g]),
        .grant(grant[g]),
        .internal_valid(internal_valid[g]),
        .internal_data(internal_data[g])
      );
    end
  endgenerate

  // Arbiter FSM state register
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) arb_state <= ARB_IDLE;
    else arb_state <= arb_next;

  // Arbiter FSM next state
  always_comb begin
    arb_next = arb_state;
    case (arb_state)
      ARB_IDLE: if (|request) arb_next = ARB_GRANT;
      ARB_GRANT: arb_next = ARB_COMPLETE;
      ARB_COMPLETE: arb_next = ARB_IDLE;
      default: arb_next = ARB_IDLE;
    endcase
  end
  
  // Round-robin selection function
  function automatic logic [1:0] rr_select(input logic [NUM_PORTS-1:0] candidates, input logic [1:0] last_priority);
    logic [1:0] offset_2bit;
    logic [1:0] check_2bit;
    for (int offset = 1; offset <= NUM_PORTS; offset++) begin
      offset_2bit = offset[1:0];
      check_2bit = (last_priority + offset_2bit) % NUM_PORTS[1:0];
      if (candidates[check_2bit]) return check_2bit;
    end
    return 2'b00;
  endfunction

  logic [NUM_PORTS-1:0] candidates [NUM_PORTS];
  logic [1:0] winner [NUM_PORTS];

  // Calculate candidates and winners
  always_comb begin
    for (int out_port = 0; out_port < NUM_PORTS; out_port++) begin
      candidates[out_port] = '0;
      for (int in_port = 0; in_port < NUM_PORTS; in_port++)
        if (request[in_port] && request_target[in_port][out_port])
          candidates[out_port][in_port] = 1'b1;
      winner[out_port] = rr_select(candidates[out_port], rr_priority[out_port]);
    end
  end
  
  // Arbiter output logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      grant <= '0;
      internal_valid <= '0;
      for (int i = 0; i < NUM_PORTS; i++) begin
        internal_data[i] <= '0;
        rr_priority[i] <= '0;
      end
    end else case (arb_state)
      ARB_IDLE: begin
        grant <= '0;
        internal_valid <= '0;
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
        grant <= '0;
        internal_valid <= '0;
      end
      default: begin
        grant <= '0;
        internal_valid <= '0;
      end
    endcase
  end

endmodule
