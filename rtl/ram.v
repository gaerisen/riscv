module ram
(
	input	wire		clk,

	input	wire		chip_select,
	input	wire		write_enable,

	input	wire		addr_valid,
	input	wire	[13:0]	addr,

	input	wire		data_valid,
	input	wire	[511:0]	data_i,

	output	wire		data_ready,
	output	wire	[511:0]	data_o
);

reg [7:0] x [0:255][0:63];

assign data_ready = chip_select ? addr_valid : 1'bz;

assign data_o = (chip_select & addr_valid) ? 	{	x[addr[13:6]][63],
							x[addr[13:6]][62],
							x[addr[13:6]][61],
							x[addr[13:6]][60],
							x[addr[13:6]][59],
							x[addr[13:6]][58],
							x[addr[13:6]][57],
							x[addr[13:6]][56],
							x[addr[13:6]][55],
							x[addr[13:6]][54],
							x[addr[13:6]][53],
							x[addr[13:6]][52],
							x[addr[13:6]][51],
							x[addr[13:6]][50],
							x[addr[13:6]][49],
							x[addr[13:6]][48],
							x[addr[13:6]][47],
							x[addr[13:6]][46],
							x[addr[13:6]][45],
							x[addr[13:6]][44],
							x[addr[13:6]][43],
							x[addr[13:6]][42],
							x[addr[13:6]][41],
							x[addr[13:6]][40],
							x[addr[13:6]][39],
							x[addr[13:6]][38],
							x[addr[13:6]][37],
							x[addr[13:6]][36],
							x[addr[13:6]][35],
							x[addr[13:6]][34],
							x[addr[13:6]][33],
							x[addr[13:6]][32],
							x[addr[13:6]][31],
							x[addr[13:6]][30],
							x[addr[13:6]][29],
							x[addr[13:6]][28],
							x[addr[13:6]][27],
							x[addr[13:6]][26],
							x[addr[13:6]][25],
							x[addr[13:6]][24],
							x[addr[13:6]][23],
							x[addr[13:6]][22],
							x[addr[13:6]][21],
							x[addr[13:6]][20],
							x[addr[13:6]][19],
							x[addr[13:6]][18],
							x[addr[13:6]][17],
							x[addr[13:6]][16],
							x[addr[13:6]][15],
							x[addr[13:6]][14],
							x[addr[13:6]][13],
							x[addr[13:6]][12],
							x[addr[13:6]][11],
							x[addr[13:6]][10],
							x[addr[13:6]][9],
							x[addr[13:6]][8],
							x[addr[13:6]][7],
							x[addr[13:6]][6],
							x[addr[13:6]][5],
							x[addr[13:6]][4],
							x[addr[13:6]][3],
							x[addr[13:6]][2],
							x[addr[13:6]][1],
							x[addr[13:6]][0]} : 
						512'bz;

initial
begin
	$readmemh("imem.hex", x);
end

always @(posedge clk)
begin
	if (chip_select & write_enable & addr_valid)
	begin
		x[addr[13:6]][63] <= data_i[511:504];
		x[addr[13:6]][62] <= data_i[503:496];
		x[addr[13:6]][61] <= data_i[495:488];
		x[addr[13:6]][60] <= data_i[487:480];
		x[addr[13:6]][59] <= data_i[479:472];
		x[addr[13:6]][58] <= data_i[471:464];
		x[addr[13:6]][57] <= data_i[463:456];
		x[addr[13:6]][56] <= data_i[455:448];
		x[addr[13:6]][55] <= data_i[447:440];
		x[addr[13:6]][54] <= data_i[439:432];
		x[addr[13:6]][53] <= data_i[431:424];
		x[addr[13:6]][52] <= data_i[423:416];
		x[addr[13:6]][51] <= data_i[415:408];
		x[addr[13:6]][50] <= data_i[407:400];
		x[addr[13:6]][49] <= data_i[399:392];
		x[addr[13:6]][48] <= data_i[391:384];
		x[addr[13:6]][47] <= data_i[383:376];
		x[addr[13:6]][46] <= data_i[375:368];
		x[addr[13:6]][45] <= data_i[367:360];
		x[addr[13:6]][44] <= data_i[359:352];
		x[addr[13:6]][43] <= data_i[351:344];
		x[addr[13:6]][42] <= data_i[343:336];
		x[addr[13:6]][41] <= data_i[335:328];
		x[addr[13:6]][40] <= data_i[327:320];
		x[addr[13:6]][39] <= data_i[319:312];
		x[addr[13:6]][38] <= data_i[311:304];
		x[addr[13:6]][37] <= data_i[303:296];
		x[addr[13:6]][36] <= data_i[295:288];
		x[addr[13:6]][35] <= data_i[287:280];
		x[addr[13:6]][34] <= data_i[279:272];
		x[addr[13:6]][33] <= data_i[271:264];
		x[addr[13:6]][32] <= data_i[263:256];
		x[addr[13:6]][31] <= data_i[255:248];
		x[addr[13:6]][30] <= data_i[247:240];
		x[addr[13:6]][29] <= data_i[239:232];
		x[addr[13:6]][28] <= data_i[231:224];
		x[addr[13:6]][27] <= data_i[223:216];
		x[addr[13:6]][26] <= data_i[215:208];
		x[addr[13:6]][25] <= data_i[207:200];
		x[addr[13:6]][24] <= data_i[199:192];
		x[addr[13:6]][23] <= data_i[191:184];
		x[addr[13:6]][22] <= data_i[183:176];
		x[addr[13:6]][21] <= data_i[175:168];
		x[addr[13:6]][20] <= data_i[167:160];
		x[addr[13:6]][19] <= data_i[159:152];
		x[addr[13:6]][18] <= data_i[151:144];
		x[addr[13:6]][17] <= data_i[143:136];
		x[addr[13:6]][16] <= data_i[135:128];
		x[addr[13:6]][15] <= data_i[127:120];
		x[addr[13:6]][14] <= data_i[119:112];
		x[addr[13:6]][13] <= data_i[111:104];
		x[addr[13:6]][12] <= data_i[103:96];
		x[addr[13:6]][11] <= data_i[95:88];
		x[addr[13:6]][10] <= data_i[87:80];
		x[addr[13:6]][9] <= data_i[79:72];
		x[addr[13:6]][8] <= data_i[71:64];
		x[addr[13:6]][7] <= data_i[63:56];
		x[addr[13:6]][6] <= data_i[55:48];
		x[addr[13:6]][5] <= data_i[47:40];
		x[addr[13:6]][4] <= data_i[39:32];
		x[addr[13:6]][3] <= data_i[31:24];
		x[addr[13:6]][2] <= data_i[23:16];
		x[addr[13:6]][1] <= data_i[15:8];
		x[addr[13:6]][0] <= data_i[7:0];
	end
end

endmodule
