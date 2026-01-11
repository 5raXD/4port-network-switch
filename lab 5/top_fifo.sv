module top_fifo (
	input clk,
	input rst,
	input start_write,
	input start_read,
	output [7:0] dout,
	output full,
	output empty
);

wire wr_en, rd_en;
wire [7:0] din;

fifo_core #(16, 8) u_fifo (
	.clk(clk),
	.rst(rst),
	.wr_en(wr_en),
	.rd_en(rd_en),
	.din(din),
	.dout(dout),
	.full(full),
	.empty(empty)
);

write_ctrl #(8) u_write_ctrl (
	.clk(clk),
	.rst(rst),
	.start_write(start_write),
	.full(full),
	.wr_en(wr_en),
	.din(din)
);

read_ctrl u_read_ctrl (
	.clk(clk),
	.rst(rst),
	.start_read(start_read),
	.empty(empty),
	.rd_en(rd_en)
);

endmodule
