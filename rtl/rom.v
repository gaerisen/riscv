module rom
(
        input   wire            cs,
	input	wire	[14:0]	addr,

	output	wire	[31:0]	data
);

reg [7:0] x [0:32767];

assign data = cs ? {
        x[addr + 3],
        x[addr + 2],
        x[addr + 1],
        x[addr + 0]
        } : 32'bz;

initial begin
	$readmemh("flash.hex", x);
end

endmodule
