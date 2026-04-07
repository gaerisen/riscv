module dualport_ram
(
	input	wire		clk,
	
	input	wire	[14:0]	addr_a,
	input	wire		chip_select_a,
	input	wire	[1:0]	op_a,
	input	wire	[31:0]	data_a_i,
	output	wire	[31:0]	data_a_o,

	input	wire	[14:0]	addr_b,
	input	wire		chip_select_b,
	input	wire	[1:0]	op_b,
	input	wire	[31:0]	data_b_i,
	output	wire	[31:0]	data_b_o
);

integer i;

reg [7:0] x [0:8191][0:3];

assign data_a_o = (chip_select_a & (op_a == 0)) ? 	{x[addr_a[14:2]][addr_a[1:0] + 2'h3], x[addr_a[14:2]][addr_a[1:0] + 2'h2], x[addr_a[14:2]][addr_a[1:0] + 2'h1], x[addr_a[14:2]][addr_a[1:0] + 2'h0]} :
							32'bz;

assign data_b_o = (chip_select_b & (op_b == 0)) ?	{x[addr_b[14:2]][addr_b[1:0] + 2'h3], x[addr_b[14:2]][addr_b[1:0] + 2'h2], x[addr_b[14:2]][addr_b[1:0] + 2'h1], x[addr_b[14:2]][addr_b[1:0] + 2'h0]} :
							32'bz;

initial
begin
	$readmemh("imem.hex", x);
end

always @(posedge clk)
begin
	if (chip_select_a)
	begin
		case (op_a)
			2'b00: begin end
			2'b01:
			begin
				x[addr_a[14:2]][addr_a[1:0]] <= data_a_i[7:0];
			end
			2'b10:
			begin
				x[addr_a[14:2]][addr_a[1:0] + 1] <= data_a_i[15:8];
				x[addr_a[14:2]][addr_a[1:0] + 0] <= data_a_i[7:0];
			end
			2'b11:
			begin
				x[addr_a[14:2]][3] <= data_a_i[31:24];
				x[addr_a[14:2]][2] <= data_a_i[23:16];
				x[addr_a[14:2]][1] <= data_a_i[15:8];
				x[addr_a[14:2]][0] <= data_a_i[7:0];
			end
		endcase
	end
	
	if (chip_select_b)
	begin
		case (op_b)
			2'b00: begin end
			2'b01:
			begin
				x[addr_b[14:2]][addr_b[1:0]] <= data_b_i[7:0];
			end
			2'b10:
			begin
				x[addr_b[14:2]][addr_b[1:0] + 1] <= data_b_i[15:8];
				x[addr_b[14:2]][addr_b[1:0] + 0] <= data_b_i[7:0];
			end
			2'b11:
			begin
				x[addr_b[14:2]][3] <= data_b_i[31:24];
				x[addr_b[14:2]][2] <= data_b_i[23:16];
				x[addr_b[14:2]][1] <= data_b_i[15:8];
				x[addr_b[14:2]][0] <= data_b_i[7:0];
			end
		endcase
	end
end

endmodule
