module icache
(
	input	wire		clk,

	input	wire		cpu_addr_valid,
	input	wire	[31:0]	cpu_addr,

	output	wire		cpu_read_data_ready,
	output	wire	[31:0]	cpu_read_data,

	output	wire		mem_addr_valid,
	output	wire	[31:0]	mem_addr,

	input	wire		mem_data_ready,
	input	wire	[511:0]	mem_data
);

reg	[31:0]	x	[0:63][0:15];
reg	[63:0]	valid;
reg	[19:0]	tag	[0:63];

assign cpu_read_data_ready =	cpu_addr_valid & valid[cpu_addr[11:6]] & (cpu_addr[31:12] == tag[cpu_addr[11:6]]);
assign cpu_read_data =		x[cpu_addr[11:6]][cpu_addr[5:2]];

assign mem_addr_valid =	(cpu_addr_valid) ? ~cpu_read_data_ready : 1'bz;
assign mem_addr =	mem_addr_valid ? cpu_addr : 32'bz;

always @(posedge clk)
begin
	if (mem_data_ready)
	begin
		x[cpu_addr[11:6]][0] <= mem_data[31:0];
		x[cpu_addr[11:6]][1] <= mem_data[63:32];
		x[cpu_addr[11:6]][2] <= mem_data[95:64];
		x[cpu_addr[11:6]][3] <= mem_data[127:96];
		x[cpu_addr[11:6]][4] <= mem_data[159:128];
		x[cpu_addr[11:6]][5] <= mem_data[191:160];
		x[cpu_addr[11:6]][6] <= mem_data[223:192];
		x[cpu_addr[11:6]][7] <= mem_data[255:224];
		x[cpu_addr[11:6]][8] <= mem_data[287:256];
		x[cpu_addr[11:6]][9] <= mem_data[319:288];
		x[cpu_addr[11:6]][10] <= mem_data[351:320];
		x[cpu_addr[11:6]][11] <= mem_data[383:352];
		x[cpu_addr[11:6]][12] <= mem_data[415:384];
		x[cpu_addr[11:6]][13] <= mem_data[447:416];
		x[cpu_addr[11:6]][14] <= mem_data[479:448];
		x[cpu_addr[11:6]][15] <= mem_data[511:480];

		tag[cpu_addr[11:6]] <= cpu_addr[31:12];
		valid[cpu_addr[11:6]] <= 1;
	end
end

endmodule
