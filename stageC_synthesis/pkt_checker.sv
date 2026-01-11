class pkt_checker extends component_base;
  
  packet expected_q[4][$];  // queue per port for expected pkts
  
  // Stats for final report
  int packets_sent;
  int packets_received;
  int packets_matched;
  int packets_mismatched;
  int packets_lost;
  int packets_unexpected;

  function new(string n, component_base p = null);
    super.new(n, p);
    packets_sent = 0;
    packets_received = 0;
    packets_matched = 0;
    packets_mismatched = 0;
    packets_lost = 0;
    packets_unexpected = 0;
  endfunction

  // Called when driver sends a pkt - add to expected list
  function void add_expected(packet p);
    packet p_copy;
    
    packets_sent++;
    
    // Add to each target port's queue
    for (int port = 0; port < 4; port++) begin
      if (p.target[port]) begin
        p_copy = p.copy();
        expected_q[port].push_back(p_copy);
        $display("[%0t] CHECKER:added expected packet to port%0d queue (tag=%0d src=%b tgt=%b data=0x%h)",
                 $time, port, p.tag, p.source, p.target, p.data);
      end
    end
  endfunction

  // Called when monitor sees output - check if we expected it
  function void check_received(int port_idx, packet p);
    automatic packet expected;
    automatic bit found = 0;
    automatic int found_idx = -1;
    
    packets_received++;
    
    $display("[%0t] CHECKER:checking received packet on port%0d (src=%b tgt=%b data=0x%h)",
             $time, port_idx, p.source, p.target, p.data);
    
    // Look for matching pkt in expected queue
    for (int i = 0; i < expected_q[port_idx].size(); i++) begin
      expected = expected_q[port_idx][i];
      if (expected.source == p.source && 
          expected.target == p.target && 
          expected.data == p.data) begin
        found = 1;
        found_idx = i;
        break;
      end
    end
    
    if (found) begin
      packets_matched++;
      expected_q[port_idx].delete(found_idx);
      $display("[%0t] CHECKER:PASS - Packet matched on port%0d (tag=%0d)",
               $time, port_idx, expected.tag);
    end else begin
      packets_unexpected++;
      $display("[%0t] CHECKER:FAIL - Unexpected packet on port%0d (src=%b tgt=%b data=0x%h)",
               $time, port_idx, p.source, p.target, p.data);
    end
  endfunction

  // Print final results at end of test
  function void report();
    automatic int total_expected_remaining = 0;
    
    $display("");
    $display("CHECKER REPORT");
    
    // Check what we didnt receive
    for (int port = 0; port < 4; port++) begin
      if (expected_q[port].size() > 0) begin
        $display("  Port%0d: %0d packets not received", port, expected_q[port].size());
        total_expected_remaining += expected_q[port].size();
      end
    end
    packets_lost = total_expected_remaining;
    
    $display("");
    $display("  Packets Sent:       %0d", packets_sent);
    $display("  Packets Received:   %0d", packets_received);
    $display("  Packets Matched:    %0d", packets_matched);
    $display("  Packets Lost:       %0d", packets_lost);
    $display("  Unexpected Packets: %0d", packets_unexpected);
    $display("");
    
    if (packets_lost == 0 && packets_unexpected == 0 && packets_matched > 0) begin
      $display("  *** TEST PASSED ***");
    end else begin
      $display("  *** TEST FAILED ***");
    end
    $display("-----------------------------");
    $display("");
  endfunction

  // Clear everything for new test
  function void reset();
    for (int port = 0; port < 4; port++) begin
      expected_q[port].delete();
    end
    packets_sent = 0;
    packets_received = 0;
    packets_matched = 0;
    packets_mismatched = 0;
    packets_lost = 0;
    packets_unexpected = 0;
  endfunction

endclass
