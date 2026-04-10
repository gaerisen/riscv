module dcache
(
	input	wire		clk,

	/* =================== */
	/* CPU-Cache interface */
	/* =================== */

	input	wire	[2:0]	cpu_mem_op,

	// Read/Write address port
	input	wire		cpu_addr_valid,
	input	wire	[31:0]	cpu_addr,

	// Write data port
	input	wire		cpu_data_valid,
	input	wire	[31:0]	cpu_write_data,

	// Read data port
	output	wire		cpu_data_ready,
	output	wire	[31:0]	cpu_read_data,

	/* ====================== */
	/* Cache-Memory interface */
	/* ====================== */

	// Read/Write address port
	output	wire		mem_addr_valid,
	output	wire	[31:0]	mem_addr,

	// Write data port
	output	wire	        mem_data_valid,
	output	wire    [511:0]	mem_write_data,

	// Read data port
	input	wire		mem_data_ready,
	input	wire	[511:0]	mem_read_data
);

reg	[31:0]	x	[0:63][0:15];
reg	[63:0]	valid;
reg	[63:0]	dirty;
reg	[19:0]	tag	[0:63];

assign cpu_data_ready = cpu_addr_valid & valid[cpu_addr[11:6]] & (cpu_addr[31:12] == tag[cpu_addr[11:6]]);
assign cpu_read_data = x[cpu_addr[11:6]][cpu_addr[5:2]];

assign mem_addr_valid = (cpu_addr_valid & ~cpu_data_ready) | mem_data_valid; 

assign mem_addr = mem_data_valid ? {tag[cpu_addr[11:6]], 12'b0} :
                mem_addr_valid ? cpu_addr : 0;
                
assign mem_data_valid = cpu_addr_valid & dirty[cpu_addr];
assign mem_write_data = mem_data_valid ? {	x[cpu_addr[11:6]][15],
                                                x[cpu_addr[11:6]][14],
                                                x[cpu_addr[11:6]][13],
                                                x[cpu_addr[11:6]][12],
                                                x[cpu_addr[11:6]][11],
                                                x[cpu_addr[11:6]][10],
                                                x[cpu_addr[11:6]][9],
                                                x[cpu_addr[11:6]][8],
                                                x[cpu_addr[11:6]][7],
                                                x[cpu_addr[11:6]][6],
                                                x[cpu_addr[11:6]][5],
                                                x[cpu_addr[11:6]][4],
                                                x[cpu_addr[11:6]][3],
                                                x[cpu_addr[11:6]][2],
                                                x[cpu_addr[11:6]][1],
                                                x[cpu_addr[11:6]][0]} : 0;

always @(posedge clk)
begin
	if (cpu_data_valid & valid[cpu_addr[11:6]] & (tag[cpu_addr[11:6]] == cpu_addr[31:12]))
	begin
		case (cpu_mem_op)
			3'b101:
			begin
				case (cpu_addr[1:0])
					2'b00: x[cpu_addr[11:6]][cpu_addr[5:2]][7:0] <= cpu_write_data[7:0];
					2'b01: x[cpu_addr[11:6]][cpu_addr[5:2]][15:8] <= cpu_write_data[7:0];
					2'b10: x[cpu_addr[11:6]][cpu_addr[5:2]][23:16] <= cpu_write_data[7:0];
					2'b11: x[cpu_addr[11:6]][cpu_addr[5:2]][31:24] <= cpu_write_data[7:0];
				endcase
			end
			3'b110:
			begin
				case (cpu_addr[1])
					1'b0: x[cpu_addr[11:6]][cpu_addr[5:2]][15:0] <= cpu_write_data[15:0];
					1'b1: x[cpu_addr[11:6]][cpu_addr[5:2]][31:16] <= cpu_write_data[15:0];
				endcase
			end
			3'b111: x[cpu_addr[11:6]][cpu_addr[5:2]] <= cpu_write_data;
			default:;
		endcase

//		x[cpu_addr[11:6]][cpu_addr[5:2]] <= cpu_write_data;
		dirty[cpu_addr[11:6]] <= 1;
	end
	else if (cpu_addr_valid & mem_addr_valid)
	begin
                if (dirty[cpu_addr]) begin
                        dirty[cpu_addr[11:6]] <= 0;
                end

                if (mem_data_ready) begin
                        x[cpu_addr[11:6]][0] <= mem_read_data[31:0];
                        x[cpu_addr[11:6]][1] <= mem_read_data[63:32];
                        x[cpu_addr[11:6]][2] <= mem_read_data[95:64];
                        x[cpu_addr[11:6]][3] <= mem_read_data[127:96];
                        x[cpu_addr[11:6]][4] <= mem_read_data[159:128];
                        x[cpu_addr[11:6]][5] <= mem_read_data[191:160];
                        x[cpu_addr[11:6]][6] <= mem_read_data[223:192];
                        x[cpu_addr[11:6]][7] <= mem_read_data[255:224];
                        x[cpu_addr[11:6]][8] <= mem_read_data[287:256];
                        x[cpu_addr[11:6]][9] <= mem_read_data[319:288];
                        x[cpu_addr[11:6]][10] <= mem_read_data[351:320];
                        x[cpu_addr[11:6]][11] <= mem_read_data[383:352];
                        x[cpu_addr[11:6]][12] <= mem_read_data[415:384];
                        x[cpu_addr[11:6]][13] <= mem_read_data[447:416];
                        x[cpu_addr[11:6]][14] <= mem_read_data[479:448];
                        x[cpu_addr[11:6]][15] <= mem_read_data[511:480];

                        tag[cpu_addr[11:6]] <= cpu_addr[31:12];
                        valid[cpu_addr[11:6]] <= 1;
                end
	end
end

endmodule
