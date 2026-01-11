module tb_fifo;

reg clk = 0;
reg rst = 1;
reg start_write = 0;
reg start_read = 0;
wire [7:0] dout;
wire full, empty;

top_fifo dut (
	.clk(clk),
	.rst(rst),
	.start_write(start_write),
	.start_read(start_read),
	.dout(dout),
	.full(full),
	.empty(empty)
);

always #5 clk = ~clk;

// Functional coverage
covergroup cg_fifo @(posedge clk);
	coverpoint full { bins full_bin = {1}; }
	coverpoint empty { bins empty_bin = {1}; }
	coverpoint dut.u_fifo.count {
		bins low = {[0:4]};
		bins med = {[5:12]};
		bins high = {[13:16]};
	}
	cross full, empty; // Invalid, but for coverage hole demo
endgroup

cg_fifo cov_inst = new();

initial begin
	#10 rst = 0;
	#10 start_write = 1;
	#200 start_write = 0;
	#50 start_read = 1;
	#200 start_read = 0;
	#100 $finish;
end

initial begin
	$dumpfile("dump.vcd");
	$dumpvars(0, tb_fifo);
end

endmodule
