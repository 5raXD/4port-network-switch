module read_ctrl (
	input clk,
	input rst,
	input start_read,
	input empty,
	output reg rd_en
);

always @(posedge clk) begin
	if (rst) begin
		rd_en <= 0;
	end else if (start_read && !empty) begin
		rd_en <= 1;
	end else begin
		rd_en <= 0;
	end
end

endmodule
