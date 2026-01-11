class agent extends component_base;
  sequencer seq;
  driver drv;
  monitor mon;
  function new(string n, component_base p = null);
    super.new(n, p);
    seq = new("sequencer", this);
    drv = new("driver", this);
    mon = new("monitor", this);
  endfunction
  // Connect driver and monitor to interface
  function void set_interface(virtual port_if vif);
    drv.set_interface(vif);
    mon.set_interface(vif);
  endfunction
  // Tell sequencer and monitor which port they are
  function void set_port(int idx);
    seq.set_port(idx);
    mon.set_port(idx);
  endfunction

endclass
