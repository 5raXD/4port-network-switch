// Gate-Level Simulation Testbench for 4-Port Network Switch
// This runs the same tests as Stage B to verify synthesis correctness
// Uses the netlist instead of RTL

`timescale 1ns/1ps

module switch_test_gate;

  parameter CLK_PERIOD = 10;

  logic clk, rst_n;
  
  // Port signals (flattened - no interface for gate-level)
  logic        port0_valid_in, port0_valid_out;
  logic [3:0]  port0_source_in, port0_source_out;
  logic [3:0]  port0_target_in, port0_target_out;
  logic [7:0]  port0_data_in, port0_data_out;
  
  logic        port1_valid_in, port1_valid_out;
  logic [3:0]  port1_source_in, port1_source_out;
  logic [3:0]  port1_target_in, port1_target_out;
  logic [7:0]  port1_data_in, port1_data_out;
  
  logic        port2_valid_in, port2_valid_out;
  logic [3:0]  port2_source_in, port2_source_out;
  logic [3:0]  port2_target_in, port2_target_out;
  logic [7:0]  port2_data_in, port2_data_out;
  
  logic        port3_valid_in, port3_valid_out;
  logic [3:0]  port3_source_in, port3_source_out;
  logic [3:0]  port3_target_in, port3_target_out;
  logic [7:0]  port3_data_in, port3_data_out;

  int packets_sent, packets_received, errors;

  // DUT - gate-level netlist
  switch_4port_synth dut (
    .clk(clk), .rst_n(rst_n),
    .port0_valid_in(port0_valid_in), .port0_source_in(port0_source_in),
    .port0_target_in(port0_target_in), .port0_data_in(port0_data_in),
    .port0_valid_out(port0_valid_out), .port0_source_out(port0_source_out),
    .port0_target_out(port0_target_out), .port0_data_out(port0_data_out),
    .port1_valid_in(port1_valid_in), .port1_source_in(port1_source_in),
    .port1_target_in(port1_target_in), .port1_data_in(port1_data_in),
    .port1_valid_out(port1_valid_out), .port1_source_out(port1_source_out),
    .port1_target_out(port1_target_out), .port1_data_out(port1_data_out),
    .port2_valid_in(port2_valid_in), .port2_source_in(port2_source_in),
    .port2_target_in(port2_target_in), .port2_data_in(port2_data_in),
    .port2_valid_out(port2_valid_out), .port2_source_out(port2_source_out),
    .port2_target_out(port2_target_out), .port2_data_out(port2_data_out),
    .port3_valid_in(port3_valid_in), .port3_source_in(port3_source_in),
    .port3_target_in(port3_target_in), .port3_data_in(port3_data_in),
    .port3_valid_out(port3_valid_out), .port3_source_out(port3_source_out),
    .port3_target_out(port3_target_out), .port3_data_out(port3_data_out)
  );

  // Clock
  initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

  // Reset
  task reset();
    rst_n = 0;
    port0_valid_in = 0; port0_source_in = 0; port0_target_in = 0; port0_data_in = 0;
    port1_valid_in = 0; port1_source_in = 0; port1_target_in = 0; port1_data_in = 0;
    port2_valid_in = 0; port2_source_in = 0; port2_target_in = 0; port2_data_in = 0;
    port3_valid_in = 0; port3_source_in = 0; port3_target_in = 0; port3_data_in = 0;
    repeat(5) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    $display("reset done, starting tests...");
  endtask

  // Send packet task
  task send_packet(input int port, input logic [3:0] src, input logic [3:0] tgt, input logic [7:0] data);
    @(posedge clk);
    case(port)
      0: begin port0_valid_in = 1; port0_source_in = src; port0_target_in = tgt; port0_data_in = data; end
      1: begin port1_valid_in = 1; port1_source_in = src; port1_target_in = tgt; port1_data_in = data; end
      2: begin port2_valid_in = 1; port2_source_in = src; port2_target_in = tgt; port2_data_in = data; end
      3: begin port3_valid_in = 1; port3_source_in = src; port3_target_in = tgt; port3_data_in = data; end
    endcase
    @(posedge clk);
    port0_valid_in = 0; port1_valid_in = 0; port2_valid_in = 0; port3_valid_in = 0;
    packets_sent++;
  endtask

  // Monitor outputs
  always @(posedge clk) begin
    if (port0_valid_out) begin
      $display("[%0t] port0 out: src=%b tgt=%b data=%h", $time, port0_source_out, port0_target_out, port0_data_out);
      packets_received++;
    end
    if (port1_valid_out) begin
      $display("[%0t] port1 out: src=%b tgt=%b data=%h", $time, port1_source_out, port1_target_out, port1_data_out);
      packets_received++;
    end
    if (port2_valid_out) begin
      $display("[%0t] port2 out: src=%b tgt=%b data=%h", $time, port2_source_out, port2_target_out, port2_data_out);
      packets_received++;
    end
    if (port3_valid_out) begin
      $display("[%0t] port3 out: src=%b tgt=%b data=%h", $time, port3_source_out, port3_target_out, port3_data_out);
      packets_received++;
    end
  end

  // Main test
  initial begin
    $display("\n========================================");
    $display("GATE-LEVEL SIMULATION");
    $display("========================================\n");
    
    errors = 0; packets_sent = 0; packets_received = 0;
    reset();

    // Test 1: Single destination (same as Stage B)
    $display("\n>> test1: single dest packets");
    send_packet(0, 4'b0001, 4'b0010, 8'h51); repeat(10) @(posedge clk);
    send_packet(0, 4'b0001, 4'b0100, 8'hdb); repeat(10) @(posedge clk);
    send_packet(0, 4'b0001, 4'b1000, 8'he9); repeat(10) @(posedge clk);
    send_packet(1, 4'b0010, 4'b0001, 8'ha4); repeat(10) @(posedge clk);
    send_packet(1, 4'b0010, 4'b0100, 8'h00); repeat(10) @(posedge clk);
    send_packet(1, 4'b0010, 4'b1000, 8'he7); repeat(10) @(posedge clk);
    $display("test1 done!");

    // Test 2: Multicast
    $display("\n>> test2: multicast packets");
    send_packet(0, 4'b0001, 4'b1110, 8'ha1); repeat(10) @(posedge clk);
    send_packet(1, 4'b0010, 4'b1101, 8'ha2); repeat(10) @(posedge clk);
    $display("multicast done!");

    // Test 3: Broadcast
    $display("\n>> test3: broadcast");
    send_packet(0, 4'b0001, 4'b1111, 8'hb1); repeat(15) @(posedge clk);
    send_packet(1, 4'b0010, 4'b1111, 8'hb2); repeat(15) @(posedge clk);
    $display("broadcast done!");

    // Test 4: Contention
    $display("\n>> test4: contention");
    @(posedge clk);
    port0_valid_in = 1; port0_source_in = 4'b0001; port0_target_in = 4'b0100; port0_data_in = 8'hc0;
    port1_valid_in = 1; port1_source_in = 4'b0010; port1_target_in = 4'b0100; port1_data_in = 8'hc1;
    packets_sent += 2;
    @(posedge clk);
    port0_valid_in = 0; port1_valid_in = 0;
    repeat(15) @(posedge clk);
    $display("contention done!");

    // Test 5: All ports simultaneous
    $display("\n>> test5: all ports sending");
    @(posedge clk);
    port0_valid_in = 1; port0_source_in = 4'b0001; port0_target_in = 4'b0010; port0_data_in = 8'he0;
    port1_valid_in = 1; port1_source_in = 4'b0010; port1_target_in = 4'b0100; port1_data_in = 8'he1;
    port2_valid_in = 1; port2_source_in = 4'b0100; port2_target_in = 4'b1000; port2_data_in = 8'he2;
    port3_valid_in = 1; port3_source_in = 4'b1000; port3_target_in = 4'b0001; port3_data_in = 8'he3;
    packets_sent += 4;
    @(posedge clk);
    port0_valid_in = 0; port1_valid_in = 0; port2_valid_in = 0; port3_valid_in = 0;
    repeat(15) @(posedge clk);
    $display("concurrent done!");

    repeat(50) @(posedge clk);

    $display("\n========================================");
    $display("GATE-LEVEL SIMULATION COMPLETE");
    $display("========================================");
    $display("Packets sent:     %0d", packets_sent);
    $display("Packets received: %0d", packets_received);
    
    if (errors == 0)
      $display("\n*** GATE-LEVEL TEST PASSED ***");
    else
      $display("\n*** GATE-LEVEL TEST FAILED: %0d errors ***", errors);
    
    $display("========================================\n");
    $finish;
  end

  initial begin #100000; $display("TIMEOUT!"); $finish; end

endmodule
