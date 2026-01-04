module switch_test;
  import packet_pkg::*;
  
  bit clk = 0;
  always #5 clk = ~clk;
  bit rst_n;
  
  port_if port0(clk, rst_n);
  port_if port1(clk, rst_n);
  port_if port2(clk, rst_n);
  port_if port3(clk, rst_n);

  switch_4port dut (.clk(clk), .rst_n(rst_n), .port0(port0), .port1(port1), .port2(port2), .port3(port3));
  
  // for coverage sampling
  logic        sample_valid;
  logic [3:0]  sample_source;
  logic [3:0]  sample_target;
  logic [7:0]  sample_data;

  // coverage module - hooks into DUT internals
  coverage_module cov_inst (
    .clk(clk),
    .rst_n(rst_n),
    .sample_valid(sample_valid),
    .pkt_source(sample_source),
    .pkt_target(sample_target),
    .pkt_data(sample_data),
    .arb_state(dut.arb_state),
    .ingress_state_p0(dut.gen_ports[0].port_inst.ingress_state),
    .ingress_state_p1(dut.gen_ports[1].port_inst.ingress_state),
    .ingress_state_p2(dut.gen_ports[2].port_inst.ingress_state),
    .ingress_state_p3(dut.gen_ports[3].port_inst.ingress_state),
    .egress_state_p0(dut.gen_ports[0].port_inst.egress_state),
    .egress_state_p1(dut.gen_ports[1].port_inst.egress_state),
    .egress_state_p2(dut.gen_ports[2].port_inst.egress_state),
    .egress_state_p3(dut.gen_ports[3].port_inst.egress_state),
    .port_requests(dut.request)
  );

  packet_vc vc[4];
  pkt_checker chk;

  // monitor outputs - checking what comes out of each port
  always @(posedge clk) begin
    if (port0.valid_out) begin
      automatic packet p = new("p0_out"); p.source = port0.source_out; p.target = port0.target_out; p.data = port0.data_out;
      $display("[%0t] omg got something on port0! src=%b tgt=%b data=%h", $time, p.source, p.target, p.data);
      chk.check_received(0, p);
    end
    if (port1.valid_out) begin
      automatic packet p = new("p1_out"); p.source = port1.source_out; p.target = port1.target_out; p.data = port1.data_out;
      $display("[%0t] port1 received pkt src=%b tgt=%b data=%h", $time, p.source, p.target, p.data);
      chk.check_received(1, p);
    end
    if (port2.valid_out) begin
      automatic packet p = new("p2_out"); p.source = port2.source_out; p.target = port2.target_out; p.data = port2.data_out;
      $display("[%0t] port2 got it! src=%b tgt=%b data=%h", $time, p.source, p.target, p.data);
      chk.check_received(2, p);
    end
    if (port3.valid_out) begin
      automatic packet p = new("p3_out"); p.source = port3.source_out; p.target = port3.target_out; p.data = port3.data_out;
      $display("[%0t] port3 output: src=%b tgt=%b data=%h", $time, p.source, p.target, p.data);
      chk.check_received(3, p);
    end
  end

  // send packet and add to checker expected list + sample for coverage
  task send_packet(int port_idx, input logic [3:0] src, input logic [3:0] tgt, input logic [7:0] dat);
    automatic packet p = new($sformatf("pkt_%0d", port_idx), port_idx);
    p.source = src;
    p.target = tgt;
    p.data = dat;
    chk.add_expected(p);
    // sample for coverage
    sample_valid = 1;
    sample_source = src;
    sample_target = tgt;
    sample_data = dat;
    @(posedge clk);
    sample_valid = 0;
    // drive it
    case (port_idx)
      0: port0.drive_packet(p);
      1: port1.drive_packet(p);
      2: port2.drive_packet(p);
      3: port3.drive_packet(p);
    endcase
  endtask

  initial begin
    rst_n = 0;
    sample_valid = 0;
    sample_source = 0;
    sample_target = 0;
    sample_data = 0;
    port0.valid_in = 0; port0.source_in = 0; port0.target_in = 0; port0.data_in = 0;
    port1.valid_in = 0; port1.source_in = 0; port1.target_in = 0; port1.data_in = 0;
    port2.valid_in = 0; port2.source_in = 0; port2.target_in = 0; port2.data_in = 0;
    port3.valid_in = 0; port3.source_in = 0; port3.target_in = 0; port3.data_in = 0;

    chk = new("pkt_checker", null);
    for (int i = 0; i < 4; i++) vc[i] = new($sformatf("vc%0d", i), null);
    vc[0].configure(port0, 0); vc[1].configure(port1, 1); vc[2].configure(port2, 2); vc[3].configure(port3, 3);

    repeat (3) @(posedge clk);
    rst_n = 1;
    $display("ok reset done, starting tests now...");
    $display("");
    $display("########## SWITCH TEST ##########");

    // test 1 - single dest all combos
    $display("");
    $display(">> test1: sending single dest packets (all src->dst combos)");
    for (int src = 0; src < 4; src++) begin
      for (int dst = 0; dst < 4; dst++) begin
        if (src != dst) begin
          automatic logic [3:0] src_oh = 4'b0001 << src;
          automatic logic [3:0] tgt_oh = 4'b0001 << dst;
          automatic logic [7:0] dat = $urandom;
          $display("  port%0d --> port%0d (dat=0x%h)", src, dst, dat);
          send_packet(src, src_oh, tgt_oh, dat);
          repeat(8) @(posedge clk);
        end
      end
    end
    repeat(10) @(posedge clk);
    $display("test1 done!");

    // test2 multicast
    $display("");
    $display(">> test2: multicast packets");
    $display("  sending to multiple ports at once");
    send_packet(0, 4'b0001, 4'b1110, 8'hA1); repeat(12) @(posedge clk);
    send_packet(1, 4'b0010, 4'b1101, 8'hA2); repeat(12) @(posedge clk);
    send_packet(2, 4'b0100, 4'b1011, 8'hA3); repeat(12) @(posedge clk);
    send_packet(3, 4'b1000, 4'b0111, 8'hA4); repeat(12) @(posedge clk);
    repeat(10) @(posedge clk);
    $display("multicast seems to work");

    // test3 broadcast  
    $display("");
    $display(">> test3: broadcast (target=1111)");
    $display("  this should go to ALL ports");
    send_packet(0, 4'b0001, 4'b1111, 8'hB1); repeat(15) @(posedge clk);
    send_packet(1, 4'b0010, 4'b1111, 8'hB2); repeat(15) @(posedge clk);
    send_packet(2, 4'b0100, 4'b1111, 8'hB3); repeat(15) @(posedge clk);
    send_packet(3, 4'b1000, 4'b1111, 8'hB4); repeat(15) @(posedge clk);
    repeat(10) @(posedge clk);
    $display("broadcast test finished");

    // test4 contention
    $display("");
    $display(">> test4: CONTENTION TEST");
    $display("  port0 and port1 both want to send to port2!!");
    $display("  arbiter should handle this with round robin");
    begin
      automatic packet p0 = new("contention_0", 0);
      automatic packet p1 = new("contention_1", 1);
      p0.target = PORT2; p0.data = 8'hC0;
      p1.target = PORT2; p1.data = 8'hC1;
      $display("  p0: src=%b tgt=%b", p0.source, p0.target);
      $display("  p1: src=%b tgt=%b", p1.source, p1.target);
      chk.add_expected(p0); chk.add_expected(p1);
      // sample coverage for both
      sample_valid = 1; sample_source = p0.source; sample_target = p0.target; sample_data = p0.data;
      @(posedge clk); sample_source = p1.source; sample_target = p1.target; sample_data = p1.data;
      @(posedge clk); sample_valid = 0;
      fork port0.drive_packet(p0); port1.drive_packet(p1); join
    end
    $display("  waiting for arbiter...");
    repeat(15) @(posedge clk);
    $display("  contention handled (hopefully lol)");

    // test5 all 4 ports at once
    $display("");
    $display(">> test5: all 4 ports sending simultaneously");
    $display("  but no contention - each goes to different dest");
    begin
      automatic packet p0 = new("conc_0", 0);
      automatic packet p1 = new("conc_1", 1);
      automatic packet p2 = new("conc_2", 2);
      automatic packet p3 = new("conc_3", 3);
      p0.target = PORT1; p0.data = 8'hE0;
      p1.target = PORT2; p1.data = 8'hE1;
      p2.target = PORT3; p2.data = 8'hE2;
      p3.target = PORT0; p3.data = 8'hE3;
      $display("  p0->p1, p1->p2, p2->p3, p3->p0");
      chk.add_expected(p0); chk.add_expected(p1); chk.add_expected(p2); chk.add_expected(p3);
      fork port0.drive_packet(p0); port1.drive_packet(p1); port2.drive_packet(p2); port3.drive_packet(p3); join
    end
    repeat(20) @(posedge clk);
    $display("  concurrent test done");

    // test6 random 
    $display("");
    $display(">> test6: random packets (16 of them)");
    for (int i = 0; i < 16; i++) begin
      automatic int port_sel = $urandom_range(0, 3);
      automatic logic [3:0] src_oh = 4'b0001 << port_sel;
      automatic logic [3:0] tgt_oh;
      automatic logic [7:0] dat = $urandom;
      do tgt_oh = $urandom_range(1, 15); while ((tgt_oh & src_oh) != 0 && tgt_oh != 4'b1111);
      $display("  rnd[%0d] port%0d->%b dat=%h", i, port_sel, tgt_oh, dat);
      send_packet(port_sel, src_oh, tgt_oh, dat);
      repeat(10) @(posedge clk);
    end
    repeat(20) @(posedge clk);
    $display("random test done");

    // test7 edge values
    $display("");
    $display(">> test7: edge case data values");
    $display("  trying data=0x00 (min) and data=0xFF (max)");
    send_packet(0, 4'b0001, 4'b0100, 8'h00); repeat(8) @(posedge clk);
    send_packet(1, 4'b0010, 4'b1000, 8'hFF); repeat(8) @(posedge clk);
    repeat(10) @(posedge clk);

    // test8 - more contention (3 ports to same dest)
    $display("");
    $display(">> test8: 3-way contention");
    $display("  ports 0,1,2 all trying to send to port3");
    begin
      automatic packet p0 = new("cont3_0", 0);
      automatic packet p1 = new("cont3_1", 1);
      automatic packet p2 = new("cont3_2", 2);
      p0.target = PORT3; p0.data = 8'hD0;
      p1.target = PORT3; p1.data = 8'hD1;
      p2.target = PORT3; p2.data = 8'hD2;
      chk.add_expected(p0); chk.add_expected(p1); chk.add_expected(p2);
      fork port0.drive_packet(p0); port1.drive_packet(p1); port2.drive_packet(p2); join
    end
    repeat(25) @(posedge clk);
    $display(" 3-way contention done");

    $display("");
    $display("##########TESTS_FINISHED##########");
    $display("");
    chk.report();
    
    $finish;
  end
endmodule
