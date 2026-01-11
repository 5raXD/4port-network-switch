module switch_port_synth #(
  parameter FIFO_DEPTH = 16,
  parameter ADDR_WIDTH = 4,
  parameter PORT_ID = 0
)(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        valid_in,
  input  logic [3:0]  source_in,
  input  logic [3:0]  target_in,
  input  logic [7:0]  data_in,
  output logic        valid_out,
  output logic [3:0]  source_out,
  output logic [3:0]  target_out,
  output logic [7:0]  data_out,
  output logic        tx_done,
  output logic        request,
  output logic [3:0]  request_target,
  output logic [15:0] request_data,
  input  logic        grant,
  input  logic        internal_valid,
  input  logic [15:0] internal_data
);

  // FSM states
  typedef enum logic {S_IDLE, S_RECEIVE} ingress_state_e;
  typedef enum logic {E_IDLE, E_OUTPUT} egress_state_e;
  
  ingress_state_e ingress_state, ingress_next;
  egress_state_e egress_state, egress_next;
  
  // FIFO storage and pointers
  logic [15:0] fifo_mem [FIFO_DEPTH];
  logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
  logic [ADDR_WIDTH:0] count;
  logic fifo_full, fifo_empty, fifo_wr_en;
  logic [15:0] fifo_wr_data, fifo_rd_data;
  logic [3:0] captured_source, captured_target;
  logic [7:0] captured_data;

  // Pack packet into 16-bit word
  function automatic logic [15:0] pack_packet(input logic [3:0] src, input logic [3:0] tgt, input logic [7:0] dat);
    return {src, tgt, dat};
  endfunction

  // Illegal packet detection functions (synthesizable)
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

  // FIFO status
  assign fifo_full = (count == FIFO_DEPTH);
  assign fifo_empty = (count == 0);
  assign fifo_rd_data = fifo_mem[rd_ptr];
  wire illegal_packet = is_illegal_packet(source_in, target_in);

  // Ingress FSM state register
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) ingress_state <= S_IDLE;
    else ingress_state <= ingress_next;

  // Capture incoming packet
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      captured_source <= '0;
      captured_target <= '0;
      captured_data <= '0;
    end else if (valid_in && !fifo_full && ingress_state == S_IDLE && !illegal_packet) begin
      captured_source <= source_in;
      captured_target <= target_in;
      captured_data <= data_in;
    end
    // Note: removed $display for synthesis
  end
  
  // Ingress FSM next state and FIFO write control
  always_comb begin
    ingress_next = ingress_state;
    fifo_wr_en = 1'b0;
    fifo_wr_data = 16'h0;
    case (ingress_state)
      S_IDLE: if (valid_in && !fifo_full && !illegal_packet) ingress_next = S_RECEIVE;
      S_RECEIVE: begin
        fifo_wr_en = 1'b1;
        fifo_wr_data = pack_packet(captured_source, captured_target, captured_data);
        ingress_next = S_IDLE;
      end
    endcase
  end

  // FIFO write logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < FIFO_DEPTH; i++) fifo_mem[i] <= 16'h0;
      wr_ptr <= '0;
    end else if (fifo_wr_en) begin
      fifo_mem[wr_ptr] <= fifo_wr_data;
      wr_ptr <= wr_ptr + 1;
    end
  end

  // Arbiter request signals
  assign request = !fifo_empty;
  assign request_target = fifo_empty ? 4'b0 : fifo_rd_data[11:8];
  assign request_data = fifo_empty ? 16'h0 : fifo_rd_data;

  // FIFO read pointer
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) rd_ptr <= '0;
    else if (grant) rd_ptr <= rd_ptr + 1;

  // FIFO count
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) count <= '0;
    else case ({fifo_wr_en, grant})
      2'b10: count <= count + 1;
      2'b01: count <= count - 1;
      default: count <= count;
    endcase
  end
  
  // Egress FSM state register
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) egress_state <= E_IDLE;
    else egress_state <= egress_next;
  
  // Egress output logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out <= 1'b0;
      source_out <= 4'b0;
      target_out <= 4'b0;
      data_out <= 8'h0;
      tx_done <= 1'b0;
    end else case (egress_state)
      E_IDLE: begin
        valid_out <= 1'b0;
        tx_done <= 1'b0;
        if (internal_valid) begin
          valid_out <= 1'b1;
          {source_out, target_out, data_out} <= internal_data;
        end
      end
      E_OUTPUT: begin
        valid_out <= 1'b0;
        tx_done <= 1'b1;
      end
    endcase
  end
  
  // Egress FSM next state
  always_comb begin
    egress_next = egress_state;
    case (egress_state)
      E_IDLE: if (internal_valid) egress_next = E_OUTPUT;
      E_OUTPUT: egress_next = E_IDLE;
    endcase
  end

endmodule
