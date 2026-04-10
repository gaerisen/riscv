module rom
(
        input   wire            clk,

        input   wire            cs,
	input	wire	[14:0]	addr,

	output	reg	[63:0]	data
);

reg [7:0] x [0:32767];

always @(posedge clk) begin
        if (cs) begin
                data <= {
                        x[addr + 7],
                        x[addr + 6],
                        x[addr + 5],
                        x[addr + 4],
                        x[addr + 3],
                        x[addr + 2],
                        x[addr + 1],
                        x[addr + 0]
                        };
        end else begin
                data <= 0;
        end
end

initial begin
	$readmemh("flash.hex", x);
end

endmodule
