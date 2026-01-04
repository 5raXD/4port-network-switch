interface port_if (input bit clk, input bit rst_n);
  import packet_pkg::*;
  
  // Input signals - testbench drives these to send packets to DUT
  logic        valid_in;
  logic [3:0]  source_in;
  logic [3:0]  target_in;
  logic [7:0]  data_in;
  
  // Output signals - DUT outputs received packets here
  logic        valid_out;
  logic [3:0]  source_out;
  logic [3:0]  target_out;
  logic [7:0]  data_out;

  // BFM task to send a packet to the switch
  // waits for clock edge, sets signals, then clears valid after one cycle
  task drive_packet(input packet p);
    @(posedge clk);
    valid_in   <= 1;
    source_in  <= p.source;
    target_in  <= p.target;
    data_in    <= p.data;
    @(posedge clk);
    valid_in   <= 0;
  endtask

  // BFM task to grab packet from DUT output
  task collect_packet(output packet p);
    @(posedge clk iff valid_out);
    p = new("monitored");
    p.source = source_out;
    p.target = target_out;
    p.data   = data_out;
  endtask

  // Modport for DUT
  modport dut_mp (
    input  valid_in, source_in, target_in, data_in,
    output valid_out, source_out, target_out, data_out
  );

  // Modport for Testbench
  modport tb_mp (
    output valid_in, source_in, target_in, data_in,
    input  valid_out, source_out, target_out, data_out
  );

endinterface
