module dcache
(
	input	wire		clk,

	/* =================== */
	/* CPU-Cache interface */
	/* =================== */

	input	wire	[3:0]	cpu_mem_mask,

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

reg state;
reg [31:0] addr_latch;
reg [31:0] data_latch;
reg [3:0] mask_latch;
reg data_waiting;

wire [31:0] addr = data_waiting ? addr_latch : cpu_addr;

assign mem_addr_valid = state == 1'b1;
assign mem_addr = mem_data_valid ? {tag[cpu_addr[11:6]], cpu_addr[11:6], 6'b0} : addr_latch;

assign mem_data_valid = state == 1'b1 & dirty[addr[11:6]];
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
                                                x[cpu_addr[11:6]][0]} : 0 ;

wire [31:0] line_write_data = cpu_write_data << {cpu_addr[1:0], 2'b0};
wire [31:0] line_write_data_latch = data_latch << {addr_latch[1:0], 2'b0};

always @(posedge clk) begin
        state <= 1'b0;
        addr_latch <= 0;
        data_latch <= 0;
        mask_latch <= 0;
        data_waiting <= 0;

        case (state)
        1'b0: begin // IDLE
                if (cpu_addr_valid & (tag[cpu_addr[11:6]] != cpu_addr[31:12])) begin
                        state <= 1'b1;
                        addr_latch <= cpu_addr;
                        data_waiting <= cpu_data_valid;
                        data_latch <= cpu_write_data;
                        mask_latch <= cpu_mem_mask;
                end
                else if (cpu_addr_valid & cpu_data_valid) begin
                        if (cpu_mem_mask[0]) begin
                                x[cpu_addr[11:6]][cpu_addr[5:2]][7:0] <= line_write_data[7:0];
                        end
                        if (cpu_mem_mask[1]) begin
                                x[cpu_addr[11:6]][cpu_addr[5:2]][15:8] <= line_write_data[15:8];
                        end
                        if (cpu_mem_mask[2]) begin
                                x[cpu_addr[11:6]][cpu_addr[5:2]][23:16] <= line_write_data[23:16];
                        end
                        if (cpu_mem_mask[3]) begin
                                x[cpu_addr[11:6]][cpu_addr[5:2]][31:24] <= line_write_data[31:24];
                        end
                end
        end
        1'b1: begin // READING from main memory
                if (dirty[addr[11:6]]) begin
                        dirty[addr[11:6]] <= 0;
                end
                if (mem_data_ready) begin
                        state <= 1'b0;

                        x[addr[11:6]][0] <= mem_read_data[31:0];
                        x[addr[11:6]][1] <= mem_read_data[63:32];
                        x[addr[11:6]][2] <= mem_read_data[95:64];
                        x[addr[11:6]][3] <= mem_read_data[127:96];
                        x[addr[11:6]][4] <= mem_read_data[159:128];
                        x[addr[11:6]][5] <= mem_read_data[191:160];
                        x[addr[11:6]][6] <= mem_read_data[223:192];
                        x[addr[11:6]][7] <= mem_read_data[255:224];
                        x[addr[11:6]][8] <= mem_read_data[287:256];
                        x[addr[11:6]][9] <= mem_read_data[319:288];
                        x[addr[11:6]][10] <= mem_read_data[351:320];
                        x[addr[11:6]][11] <= mem_read_data[383:352];
                        x[addr[11:6]][12] <= mem_read_data[415:384];
                        x[addr[11:6]][13] <= mem_read_data[447:416];
                        x[addr[11:6]][14] <= mem_read_data[479:448];
                        x[addr[11:6]][15] <= mem_read_data[511:480];

                        if (data_waiting) begin
                                if (mask_latch[0]) begin
			        	x[addr[11:6]][addr[5:2]][7:0] <= line_write_data_latch[7:0];
                                end
                                if (mask_latch[1]) begin
        				x[addr[11:6]][addr[5:2]][15:8] <= line_write_data_latch[15:8];
                                end
                                if (mask_latch[2]) begin
                                        x[addr[11:6]][addr[5:2]][23:16] <= line_write_data_latch[23:16];
                                end
                                if (mask_latch[3]) begin
                                        x[addr[11:6]][addr[5:2]][31:24] <= line_write_data_latch[31:24];
                                end
                                dirty[addr[11:6]] <= 1;
                        end

                        tag[addr[11:6]] <= addr[31:12];
                        valid[addr[11:6]] <= 1;
                end else begin
                        state <= 1'b1;
                        addr_latch <= addr_latch;
                        data_waiting <= data_waiting;
                        data_latch <= data_latch;
                        mask_latch <= mask_latch;
                end
        end
        endcase
end

endmodule
