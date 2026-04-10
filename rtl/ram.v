module ram
(
	input	wire		clk,

        input   wire            cs,
	input	wire		we,

	input	wire	[13:0]	addr,

	input	wire	[63:0]	data_i,
	output	reg	[63:0]	data_o
);

reg [7:0] x [0:16383];

always @(posedge clk)
begin
        if (cs & we) begin
                x[addr + 7] <= data_i[7:0];
                x[addr + 6] <= data_i[15:8];
                x[addr + 5] <= data_i[23:16];
                x[addr + 4] <= data_i[31:24];
                x[addr + 3] <= data_i[39:32];
                x[addr + 2] <= data_i[47:40];
                x[addr + 1] <= data_i[55:48];
                x[addr + 0] <= data_i[63:56];
        end
        else if (cs) begin
                data_o <= {
                        x[addr + 0],
                        x[addr + 1],
                        x[addr + 2],
                        x[addr + 3],
                        x[addr + 4],
                        x[addr + 5],
                        x[addr + 6],
                        x[addr + 7]
                        };
        end
end

initial begin
	$readmemh("ram.hex", x);
end

endmodule
