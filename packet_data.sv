typedef enum logic [1:0] {
  SINGLE_DEST    = 2'b00,
  MULTICAST      = 2'b01,
  BROADCAST_TYPE = 2'b10
} packet_type_e;

// Base packet class - has constraints for legal packets
class packet;
  string            name;
  rand logic [3:0]  source;
  rand logic [3:0]  target;
  rand logic [7:0]  data;
  packet_type_e     pkt_type;
  
  static int packet_count = 0;  // shared counter for unique tags
  int tag;

  // Source must be one-hot
  constraint valid_source {
    source inside {4'b0001, 4'b0010, 4'b0100, 4'b1000};
  }

  // Target cant be zero
  constraint valid_target {
    target != 4'b0000;
  }

  // No self loop unless broadcast
  constraint no_source_in_target {
    (target & source) == 4'b0000 || target == 4'b1111;
  }

  function new(string name = "packet", int port_idx = -1);
    this.name = name;
    this.tag = packet_count++;
    if (port_idx >= 0 && port_idx < 4) begin
      this.source = 4'b0001 << port_idx;
    end
  endfunction

  // Returns packet type based on target bits
  function packet_type_e get_type();
    int num_targets;
    num_targets = $countones(target);
    if (target == 4'b1111)
      return BROADCAST_TYPE;
    else if (num_targets > 1)
      return MULTICAST;
    else
      return SINGLE_DEST;
  endfunction

  function string get_name();
    return name;
  endfunction

  // Print packet info
  function void print(string format = "hex");
    string type_str;
    pkt_type = get_type();
    case (pkt_type)
      SINGLE_DEST:    type_str = "SINGLE";
      MULTICAST:      type_str = "MULTICAST";
      BROADCAST_TYPE: type_str = "BROADCAST";
    endcase
    
    if (format == "bin")
      $display("[%s] tag=%0d type=%s src=%b tgt=%b data=%b", 
               name, tag, type_str, source, target, data);
    else if (format == "dec")
      $display("[%s] tag=%0d type=%s src=%0d tgt=%0d data=%0d", 
               name, tag, type_str, source, target, data);
    else
      $display("[%s] tag=%0d type=%s src=%b tgt=%b data=0x%h", 
               name, tag, type_str, source, target, data);
  endfunction

  function bit compare(packet other);
    return (this.source == other.source) && 
           (this.target == other.target) && 
           (this.data == other.data);
  endfunction

  function packet copy();
    packet p = new(this.name);
    p.source = this.source;
    p.target = this.target;
    p.data = this.data;
    p.tag = this.tag;
    return p;
  endfunction

endclass

// Single destination packet - target has exactly 1 bit set
class single_packet extends packet;
  constraint single_target {
    target inside {4'b0001, 4'b0010, 4'b0100, 4'b1000};
    target != source;
  }

  function new(string name = "single_pkt", int port_idx = -1);
    super.new(name, port_idx);
  endfunction
endclass

// Multicast packet - target has 2 or 3 bits set
class multicast_packet extends packet;
  constraint multi_target {
    target inside {4'b0011, 4'b0101, 4'b0110, 4'b1001, 4'b1010, 4'b1100,
                   4'b0111, 4'b1011, 4'b1101, 4'b1110};
    (target & source) == 4'b0000;  // cant include self
  }

  function new(string name = "multicast_pkt", int port_idx = -1);
    super.new(name, port_idx);
  endfunction
endclass

// Broadcast packet - goes to all 4 ports
class broadcast_packet extends packet;
  constraint bcast_target {
    target == 4'b1111;
  }

  function new(string name = "broadcast_pkt", int port_idx = -1);
    super.new(name, port_idx);
  endfunction
endclass
