class driver extends component_base;
  virtual port_if vif;

  function new(string n, component_base p = null);
    super.new(n, p);
  endfunction

  function void set_interface(virtual port_if vif);
    this.vif = vif;
  endfunction

  // Actually sends packet thru the interface
  task drive(packet p);
    vif.drive_packet(p);
    $display("[%0t] DRIVER %s: Sent packet tag=%0d src=%b tgt=%b data=0x%h", 
             $time, pathname(), p.tag, p.source, p.target, p.data);
  endtask

endclass
