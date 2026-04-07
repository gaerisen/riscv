module riscv_core
(
	input	wire		clk,
	input	wire		rst,

	output	wire		ext_addr_valid,
	output	wire	[31:0]	ext_addr,

	output	wire		ext_write_data_valid,
	output	wire	[511:0]	ext_write_data,

	input	wire		ext_read_data_ready,
	input	wire	[511:0]	ext_read_data,

	input	wire		ext_timer_tick,

	input	wire		ext_irq
);

wire		icache_addr_valid;
wire	[31:0]	icache_addr;
wire		icache_data_ready;
wire	[31:0]	icache_data;
wire	[2:0]	dcache_mem_op;
wire		dcache_addr_valid;
wire	[31:0]	dcache_addr;
wire		dcache_read_data_ready;
wire	[31:0]	dcache_read_data;
wire		dcache_write_data_valid;
wire	[31:0]	dcache_write_data;
wire		icache_ext_addr_valid;
wire	[31:0]	icache_ext_addr;
wire		dcache_ext_addr_valid;
wire	[31:0]	dcache_ext_addr;
wire		timer_irq;

assign	ext_addr_valid = (icache_ext_addr_valid | dcache_ext_addr_valid);
assign	ext_addr =	icache_ext_addr_valid ? icache_ext_addr :
			dcache_ext_addr_valid ? dcache_ext_addr :
						32'b0;

assign dcache_write_data_valid = dcache_mem_op[2];

riscv_hart hart0
(
	.clk(clk),
	.rst(rst),

	// Icache port
	.icache_addr_valid(icache_addr_valid),
	.icache_addr(icache_addr),

	.icache_data_ready(icache_data_ready),
	.icache_data(icache_data),

	// Dcache port
	.dcache_mem_op(dcache_mem_op),

	.dcache_addr_valid(dcache_addr_valid),
	.dcache_addr(dcache_addr),

	.dcache_read_data_ready(dcache_read_data_ready),
	.dcache_read_data(dcache_read_data),

	.dcache_write_data_valid(dcache_write_data_valid),
	.dcache_write_data(dcache_write_data),

	// Interrupt port
	.hardware_irq(ext_irq),
	.timer_irq(timer_irq)
);

icache imem
(
	.clk(clk),

	// CPU address port
	.cpu_addr_valid(icache_addr_valid),
	.cpu_addr_cacheable(icache_addr < 32'hc000),
	.cpu_addr(icache_addr),

	// CPU data port
	.cpu_read_data_ready(icache_data_ready),
	.cpu_read_data(icache_data),

	// External address port
	.mem_addr_valid(icache_ext_addr_valid),
	.mem_addr(icache_ext_addr),

	// External data port
	.mem_read_data_ready(ext_read_data_ready),
	.mem_read_data(ext_read_data)
);

dcache dmem
(
	.clk(clk),

	.cpu_mem_op(dcache_mem_op),

	// CPU address port
	.cpu_addr_valid(dcache_addr_valid),
	.cpu_addr_cacheable(dcache_addr < 32'hc000),
	.cpu_addr(dcache_addr),

	// CPU data write port
	.cpu_write_data_valid(dcache_write_data_valid),
	.cpu_write_data(dcache_write_data),

	// CPU data read port
	.cpu_read_data_ready(dcache_read_data_ready),
	.cpu_read_data(dcache_read_data),

	// External address port
	.mem_addr_valid(dcache_ext_addr_valid),
	.mem_addr(dcache_ext_addr),

	// External data write port
	.mem_write_data_valid(ext_write_data_valid),
	.mem_write_data(ext_write_data),

	// External data read port
	.mem_read_data_ready(ext_read_data_ready),
	.mem_read_data(ext_read_data)
);

timer rtclock
(
	.clk(clk),
	.rtc(ext_timer_tick),

	.chip_select(dcache_addr[31:4] == 28'hc00),
	.addr_valid(dcache_addr_valid),
	.addr(dcache_addr[3:0]),
	.op(dcache_mem_op[2]),
	.data_valid(dcache_write_data_valid),
	.data_i(dcache_write_data),
	.data_ready(dcache_read_data_ready),
	.data_o(dcache_read_data),

	.interrupt(timer_irq)
);

endmodule
