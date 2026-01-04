class monitor extends component_base;
  virtual port_if vif;
  int port_idx;
  
  mailbox #(packet) rx_mbx;  // sends captured pkts to checker

  function new(string n, component_base p = null);
    super.new(n, p);
    rx_mbx = new();
  endfunction

  function void set_interface(virtual port_if vif);
    this.vif = vif;
  endfunction

  function void set_port(int idx);
    this.port_idx = idx;
  endfunction

  // Get single packet manually
  task collect(output packet p);
    vif.collect_packet(p);
    $display("[%0t] MONITOR %s: Received packet src=%b tgt=%b data=0x%h", 
             $time, pathname(), p.source, p.target, p.data);
  endtask

  // Run forever watching for valid outputs
  task run();
    packet p;
    forever begin
      @(posedge vif.clk);
      if (vif.valid_out) begin
        p = new($sformatf("mon_port%0d", port_idx));
        p.source = vif.source_out;
        p.target = vif.target_out;
        p.data   = vif.data_out;
        $display("[%0t] MONITOR %s: Received packet src=%b tgt=%b data=0x%h", 
                 $time, pathname(), p.source, p.target, p.data);
        rx_mbx.put(p);  // send to checker
      end
    end
  endtask

endclass
