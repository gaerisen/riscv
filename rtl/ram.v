module ram
(
	input	wire		clk,

        input   wire            cs,
	input	wire		we,
        input   wire    [3:0]   mask,

	input	wire	[13:0]	addr,

	input	wire	[31:0]	data_i,
	output	wire	[31:0]	data_o
);

reg [7:0] x [0:16383];

assign data_o = cs ? {
        x[addr + 3],
        x[addr + 2],
        x[addr + 1],
        x[addr + 0]
        } : 32'bz;

always @(posedge clk)
begin
        if (cs & we) begin
                if (mask[0]) begin
                        x[addr + 0] <= data_i[7:0];
                end
                if (mask[1]) begin
                        x[addr + 1] <= data_i[15:8];
                end
                if (mask[2]) begin
                        x[addr + 2] <= data_i[23:16];
                end
                if (mask[3]) begin
                        x[addr + 3] <= data_i[31:24];
                end
        end
end

initial begin
	$readmemh("ram.hex", x);
end

endmodule
