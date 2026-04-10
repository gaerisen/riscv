module riscv_cpu
(
	input	wire		clk,
	input	wire		rst,

	output	wire	[31:0]	addr,

        output  wire            write_enable,
	output	wire	[63:0]	write_data,
	input	wire	[63:0]	read_data,

	input	wire		irq
);

wire i_addr_valid;
wire [31:0] i_addr;

wire i_data_ready;
wire [31:0] i_data;

wire d_addr_valid;
wire [31:0] d_addr;

wire d_data_ready;
wire [31:0] d_read_data;

wire d_data_valid;
wire [31:0] d_write_data;

wire [2:0] d_mem_op;

wire timer_irq = 0;


riscv_hart hart0
(
	.clk(clk),
	.rst(rst),

	// Icache port
	.i_addr_valid(i_addr_valid),
	.i_addr(i_addr),

	.i_data_ready(i_data_ready),
	.i_data(i_data),

	// Dcache port
	.d_mem_op(d_mem_op),

	.d_addr_valid(d_addr_valid),
	.d_addr(d_addr),

	.d_data_ready(d_data_ready),
	.d_read_data(d_read_data),

	.d_data_valid(d_data_valid),
	.d_write_data(d_write_data),

	// Interrupt port
	.hardware_irq(irq),
	.timer_irq(timer_irq)
);

wire icache_addr_valid;
wire [31:0] icache_addr;
wire icache_data_ready;
wire [511:0] icache_data;

wire dcache_addr_valid;
wire [31:0] dcache_addr;
wire dcache_data_ready;
wire [511:0] dcache_read_data;
wire dcache_data_valid;
wire [511:0] dcache_write_data;

icache imem
(
	.clk(clk),

	// CPU address port
	.cpu_addr_valid(i_cacheable),
	.cpu_addr(i_addr),

	// CPU data port
	.cpu_read_data_ready(i_data_ready),
	.cpu_read_data(i_data),

	// External address port
	.mem_addr_valid(icache_addr_valid),
	.mem_addr(icache_addr),

	// External data port
	.mem_data_ready(icache_data_ready),
	.mem_data(icache_data)
);

dcache dmem
(
	.clk(clk),

	.cpu_mem_op(d_mem_op),

	// CPU address port
	.cpu_addr_valid(d_cacheable),
	.cpu_addr(d_addr),

	// CPU data write port
	.cpu_data_valid(d_data_valid),
	.cpu_write_data(d_write_data),

	// CPU data read port
	.cpu_data_ready(d_data_ready),
	.cpu_read_data(d_read_data),

	// External address port
	.mem_addr_valid(dcache_addr_valid),
	.mem_addr(dcache_addr),

	// External data write port
	.mem_data_valid(dcache_data_valid),
	.mem_write_data(dcache_write_data),

	// External data read port
	.mem_data_ready(dcache_data_ready),
	.mem_read_data(dcache_read_data)
);

wire i_cacheable = i_addr_valid & i_addr < 32'hc000;
wire d_cacheable = d_addr_valid & d_addr < 32'hc000;

wire icache_waiting = i_cacheable & icache_addr_valid;
wire dcache_waiting = d_cacheable & dcache_addr_valid;

wire ctrl_addr_valid = icache_waiting | dcache_waiting;

wire [31:0] ctrl_addr = (i_cacheable & icache_addr_valid) ? icache_addr :
                     (d_cacheable & dcache_addr_valid) ? dcache_addr :
                         32'b0;

wire ctrl_data_ready;
wire [511:0] ctrl_read_data;

assign icache_data_ready = icache_waiting & ctrl_data_ready;
assign icache_data = icache_data_ready ? ctrl_read_data : 0;

assign dcache_data_ready = ~icache_waiting & dcache_waiting & ctrl_data_ready;
assign dcache_read_data = dcache_data_ready ? ctrl_read_data : 0;

mem_ctrl mem_ctrl (
        .clk(clk),
        .rst(rst),

        .cpu_addr_valid(ctrl_addr_valid),
        .cpu_addr(ctrl_addr),

        .cpu_write_enable(dcache_data_valid),
        .cpu_write_data(dcache_write_data),

        .cpu_data_ready(ctrl_data_ready),
        .cpu_read_data(ctrl_read_data),

        .ext_addr(addr),
        .ext_data_i(read_data),
        .ext_write_enable(write_enable),
        .ext_data_o(write_data)
);

endmodule
