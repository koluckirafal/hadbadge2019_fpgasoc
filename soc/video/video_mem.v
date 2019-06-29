/*
This instantiates the video memory and connects it to the HDMI encoder. On the CPU end, it has direct access to the line buffer; on the
video end, it allows a 640x480 image generator to connect to the other end of the video memory.

ToDo: also provide an interface for a native 480x320 display.
*/

module video_mem #(
	parameter integer ADDR_WIDTH = 11 // must be >=9
) (
	input clk,
	input reset,
	input [ADDR_WIDTH-1:0] addr,
	input [23:0] data_in,
	input wen, ren,
	output [23:0] data_out,
	output reg [ADDR_WIDTH-1:0] curr_vid_addr,
	output reg next_field_out,

	input pixel_clk,
	input fetch_next,
	input next_line,
	input next_field,
	output [7:0] red,
	output [7:0] green,
	output [7:0] blue
);

reg [ADDR_WIDTH-1:0] video_addr;
wire [23:0] video_data;
assign red=video_data[7:0];
assign green=video_data[15:8];
assign blue=video_data[23:16];

ram_dp_24x2048 ram (
	.ResetA(reset),
	.ClockA(clk),
	.ClockEnA(1'b1),
	.DataInA(data_in),
	.AddressA(addr),
	.WrA(wen),
	.QA(data_out),
	.WrB(0),

	.ResetB(reset),
	.ClockB(pixel_clk),
	.ClockEnB(1'b1),
	.DataInB('b0),
	.AddressB(video_addr),
	.QB(video_data)
);

//The video display is 640x480, we want to show 480x320...
//Means we need to dup lines...probably better to do it with interpolating, but meh :/
// 640/480 = 3/4
// 480/320 = 2/3

reg [1:0] x_skip_ctr;
reg [1:0] y_skip_ctr;
reg [ADDR_WIDTH-1:0] video_addr_clkxing[1:0];
reg next_field_xing[1:0];

always @(posedge clk) begin
	//clock domain crossing things
	curr_vid_addr <= video_addr_clkxing[1];
	video_addr_clkxing[1] <= video_addr_clkxing[0];
	video_addr_clkxing[0] <= video_addr;
	next_field_out <= next_field_xing[1];
	next_field_xing[1] <= next_field_xing[0];
	next_field_xing[0] <= next_field;
end

always @(posedge pixel_clk) begin
	if (reset) begin
		video_addr <= 0;
	end else begin
		if (next_field) begin
			x_skip_ctr <= 0;
			y_skip_ctr <= 0;
			video_addr <= 0;
		end else if (next_line) begin
			y_skip_ctr <= (y_skip_ctr == 2) ? 0 : y_skip_ctr+1;
			if (y_skip_ctr != 2) begin
				video_addr[ADDR_WIDTH-1:9] <= video_addr[ADDR_WIDTH-1:9]+1;
			end
			video_addr[8:0] <= 0;
		end else if (fetch_next) begin
			x_skip_ctr <= x_skip_ctr + 1;
			if (x_skip_ctr != 3) begin
				video_addr <= video_addr + 1;
			end
		end
	end
end

endmodule