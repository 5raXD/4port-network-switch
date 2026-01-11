class sequencer extends component_base;
  int port_idx;
  
  function new(string n, component_base p = null);
    super.new(n, p);
    port_idx = 0;
  endfunction

  function void set_port(int idx);
    port_idx = idx;
  endfunction

  // Get random packet - picks type randomly
  function packet get_next_packet();
    packet p;
    int pkt_type;
    
    // 0=single, 1=multicast, 2=broadcast
    pkt_type = $urandom_range(0, 2);
    
    case (pkt_type)
      0: begin
        automatic single_packet sp = new("single_pkt", port_idx);
        if (!sp.randomize())
          $display("[%0t] ERROR: Randomization failed for single_packet", $time);
        p = sp;
      end
      1: begin
        automatic multicast_packet mp = new("multicast_pkt", port_idx);
        if (!mp.randomize())
          $display("[%0t] ERROR: Randomization failed for multicast_packet", $time);
        p = mp;
      end
      2: begin
        automatic broadcast_packet bp = new("broadcast_pkt", port_idx);
        if (!bp.randomize())
          $display("[%0t] ERROR: Randomization failed for broadcast_packet", $time);
        p = bp;
      end
    endcase
    
    return p;
  endfunction

  // Specific packet generators - for directed tests
  function packet get_single_packet();
    automatic single_packet sp = new("single_pkt", port_idx);
    if (!sp.randomize())
      $display("[%0t] ERROR: Randomization failed for single_packet", $time);
    return sp;
  endfunction

  function packet get_multicast_packet();
    automatic multicast_packet mp = new("multicast_pkt", port_idx);
    if (!mp.randomize())
      $display("[%0t] ERROR: Randomization failed for multicast_packet", $time);
    return mp;
  endfunction

  function packet get_broadcast_packet();
    automatic broadcast_packet bp = new("broadcast_pkt", port_idx);
    if (!bp.randomize())
      $display("[%0t] ERROR: Randomization failed for broadcast_packet", $time);
    return bp;
  endfunction

endclass
