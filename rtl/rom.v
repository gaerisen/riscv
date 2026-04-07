module rom
(
	input	wire		chip_select,

	input	wire		addr_valid,
	input	wire	[14:0]	addr,

	output	reg		data_ready,
	output	reg	[511:0]	data
);

reg [7:0] x [0:511][0:63];

assign data_ready = chip_select ? addr_valid : 1'bz;

assign data = (chip_select & addr_valid) ? 	{	x[addr[14:6]][63],
							x[addr[14:6]][62],
							x[addr[14:6]][61],
							x[addr[14:6]][60],
							x[addr[14:6]][59],
							x[addr[14:6]][58],
							x[addr[14:6]][57],
							x[addr[14:6]][56],
							x[addr[14:6]][55],
							x[addr[14:6]][54],
							x[addr[14:6]][53],
							x[addr[14:6]][52],
							x[addr[14:6]][51],
							x[addr[14:6]][50],
							x[addr[14:6]][49],
							x[addr[14:6]][48],
							x[addr[14:6]][47],
							x[addr[14:6]][46],
							x[addr[14:6]][45],
							x[addr[14:6]][44],
							x[addr[14:6]][43],
							x[addr[14:6]][42],
							x[addr[14:6]][41],
							x[addr[14:6]][40],
							x[addr[14:6]][39],
							x[addr[14:6]][38],
							x[addr[14:6]][37],
							x[addr[14:6]][36],
							x[addr[14:6]][35],
							x[addr[14:6]][34],
							x[addr[14:6]][33],
							x[addr[14:6]][32],
							x[addr[14:6]][31],
							x[addr[14:6]][30],
							x[addr[14:6]][29],
							x[addr[14:6]][28],
							x[addr[14:6]][27],
							x[addr[14:6]][26],
							x[addr[14:6]][25],
							x[addr[14:6]][24],
							x[addr[14:6]][23],
							x[addr[14:6]][22],
							x[addr[14:6]][21],
							x[addr[14:6]][20],
							x[addr[14:6]][19],
							x[addr[14:6]][18],
							x[addr[14:6]][17],
							x[addr[14:6]][16],
							x[addr[14:6]][15],
							x[addr[14:6]][14],
							x[addr[14:6]][13],
							x[addr[14:6]][12],
							x[addr[14:6]][11],
							x[addr[14:6]][10],
							x[addr[14:6]][9],
							x[addr[14:6]][8],
							x[addr[14:6]][7],
							x[addr[14:6]][6],
							x[addr[14:6]][5],
							x[addr[14:6]][4],
							x[addr[14:6]][3],
							x[addr[14:6]][2],
							x[addr[14:6]][1],
							x[addr[14:6]][0]} :
						512'bz;

initial
begin
	$readmemh("imem.hex", x);
end

endmodule
