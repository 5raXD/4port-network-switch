module write_ctrl #(
	parameter WIDTH = 8
) (
	input clk,
	input rst,
	input start_write,
	input full,
	output reg wr_en,
	output reg [WIDTH-1:0] din
);

reg [7:0] counter;

always @(posedge clk) begin
	if (rst) begin
		wr_en <= 0;
		din <= 0;
		counter <= 0;
	end else if (start_write && !full) begin
		wr_en <= 1;
		din <= counter;
		counter <= counter + 1;
	end else begin
		wr_en <= 0;
	end
end

endmodule
