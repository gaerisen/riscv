`timescale 1ps / 1ps

// Simple 1-cycle dmem for testing the LSU

module dmem
#(
	parameter SIZE = 64, // 64 KiB
	parameter ADDRBITS = $clog2(SIZE)
)(
	input clk,
	input rst,
	
	input [31:0] addr,
	output logic [7:0] data_o,

	input cs,
	input we,

	input [7:0] data_i
);

initial
begin
	check_power_of_2:
	assert ((SIZE & (SIZE - 1)) == 0)
	else
		$error("Dmem size in bytes isn't a power of 2");
end

logic [7:0] x [0:SIZE-1] /* verilator public */;
logic [7:0] data_next;

always_comb
begin
	data_next = 0;

	if (cs & ~we) begin
		data_next = x[addr[ADDRBITS-1:0]+0];
	end
end

always_ff @(posedge clk, posedge rst)
begin
	if (rst) begin
		data_o <= 0;
		for (int i = 0; i < SIZE; i++) begin
			x[i] = 8'b0;
		end
	end else begin
		data_o <= data_next;

		if (cs && we) begin
			x[addr[ADDRBITS-1:0]] <= data_i;
		end
	end
end

endmodule: dmem
