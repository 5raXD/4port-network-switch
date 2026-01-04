class packet_vc extends component_base;
  agent agt;
  virtual port_if vif;
  int port_idx;

  function new(string n, component_base p = null);
    super.new(n, p);
    agt = new("agent", this);
  endfunction

  // Setup the VC with interface and port number
  function void configure(virtual port_if vif, int port_idx);
    this.vif = vif;
    this.port_idx = port_idx;
    agt.set_interface(vif);
    agt.set_port(port_idx);
  endfunction

  // Send N random packets
  task run(int num_packets);
    packet p;
    
    $display("[%0t] VC %s: Starting stimulus generation with %0d packets", 
             $time, pathname(), num_packets);
    
    for (int i = 0; i < num_packets; i++) begin
      p = agt.seq.get_next_packet();
      p.print();
      agt.drv.drive(p);
      repeat(5) @(posedge vif.clk);  // wait between packets
    end
    
    $display("[%0t] VC %s: Completed stimulus generation", $time, pathname());
  endtask

  // Directed test - only single dest packets
  task run_single(int num_packets);
    packet p;
    $display("[%0t] VC %s: Running %0d single-dest packets", $time, pathname(), num_packets);
    for (int i = 0; i < num_packets; i++) begin
      p = agt.seq.get_single_packet();
      p.print();
      agt.drv.drive(p);
      repeat(5) @(posedge vif.clk);
    end
  endtask

  // Directed test - only multicast packets
  task run_multicast(int num_packets);
    packet p;
    $display("[%0t] VC %s: Running %0d multicast packets", $time, pathname(), num_packets);
    for (int i = 0; i < num_packets; i++) begin
      p = agt.seq.get_multicast_packet();
      p.print();
      agt.drv.drive(p);
      repeat(5) @(posedge vif.clk);
    end
  endtask

  // Directed test - only broadcast packets
  task run_broadcast(int num_packets);
    packet p;
    $display("[%0t] VC %s: Running %0d broadcast packets", $time, pathname(), num_packets);
    for (int i = 0; i < num_packets; i++) begin
      p = agt.seq.get_broadcast_packet();
      p.print();
      agt.drv.drive(p);
      repeat(5) @(posedge vif.clk);
    end
  endtask

endclass
