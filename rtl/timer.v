module timer
(
	input	wire		clk,
	input	wire		rtc,

	input	wire		chip_select,
	input	wire		addr_valid,
	input	wire	[3:0]	addr,
	input	wire		op,
	input	wire		data_valid,
	input	wire	[31:0]	data_i,
	output	wire		data_ready,
	output	wire	[31:0]	data_o,

	output	wire		interrupt
);

reg	[63:0]	mtime;
reg	[63:0]	mtimecmp;

initial
begin
	mtime = 0;
	mtimecmp = 0;
end

assign data_ready = chip_select ? addr_valid : 1'bz;

assign data_o = (chip_select & addr_valid) ? (	(addr == 4'h0) ?	mtime[31:0] :
						(addr == 4'h4) ?	mtime[63:32] :
						(addr == 4'h8) ?	mtimecmp[31:0] :
						(addr == 4'hc) ?	mtimecmp[63:32] :
									32'h0 ) :
						32'bz;


assign interrupt = (mtime > mtimecmp);

always @(posedge clk)
begin
	if (chip_select & op & data_valid & addr_valid)
	begin
		case (addr)
			4'h0: mtime[31:0] <= data_i;
			4'h4: mtime[63:32] <= data_i;
			4'h8: mtimecmp[31:0] <= data_i;
			4'hc: mtimecmp[63:32] <= data_i;
			default:;
		endcase
	end
	else if (rtc)
	begin
		mtime <= mtime + 1;
	end
end

endmodule
