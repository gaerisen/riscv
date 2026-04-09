module riscv_cpu
(
	input	wire		clk,
	input	wire		rst,

	output	wire		addr_valid,
	output	wire	[31:0]	addr,

	output	wire		write_data_valid,
	output	wire	[511:0]	write_data,

	input	wire		read_data_ready,
	input	wire	[511:0]	read_data,

	input	wire		irq,

        output  wire            uart_valid,
        output  wire    [7:0]   uart_o,

        output  wire            uart_ready,
        input   wire    [7:0]   uart_i
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

wire timer_irq;


wire icache_data_ready;
wire [31:0] icache_data;

wire icache_ext_addr_valid;
wire [31:0] icache_ext_addr;

wire icache_ext_data_ready;
wire [511:0] icache_ext_data;

wire dcache_data_ready;
wire [31:0] dcache_data;

wire dcache_ext_addr_valid;
wire [31:0] dcache_ext_addr;

wire dcache_ext_data_ready;
wire [511:0] dcache_ext_read_data;

wire dcache_ext_data_valid;
wire [511:0] dcache_ext_write_data;


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

	.d_read_data_ready(d_data_ready),
	.d_read_data(d_read_data),

	.d_write_data_valid(d_data_valid),
	.d_write_data(d_write_data),

	// Interrupt port
	.hardware_irq(irq),
	.timer_irq(timer_irq)
);

// Memory access/address resolution

wire i_cacheable = i_addr < 32'hc000;
wire d_cacheable = d_addr < 32'hc000;

assign addr_valid =     (i_addr_valid & (       ~i_cacheable |
                                                icache_ext_addr_valid)) |
                        (d_addr_valid & (       ~d_cacheable |
                                                dcache_ext_addr_valid));

assign addr =   ~i_cacheable ?              i_addr :
                icache_ext_addr_valid ?     icache_ext_addr :
                ~d_cacheable ?              d_addr :
                dcache_ext_addr_valid ?     dcache_ext_addr :
                                            0;

wire i_data_waiting = ~i_cacheable | icache_ext_addr_valid;
wire d_data_waiting = ~d_cacheable | dcache_ext_addr_valid;

assign i_data_ready = i_data_waiting & read_data_ready;
assign d_data_ready = ~i_data_waiting & d_data_waiting & read_data_ready;

icache imem
(
	.clk(clk),

	// CPU address port
	.cpu_addr_valid(i_cacheable),
	.cpu_addr(i_addr),

	// CPU data port
	.cpu_read_data_ready(icache_data_ready),
	.cpu_read_data(icache_data),

	// External address port
	.mem_addr_valid(icache_ext_addr_valid),
	.mem_addr(icache_ext_addr),

	// External data port
	.mem_read_data_ready(icache_ext_data_ready),
	.mem_read_data(icache_ext_data)
);

dcache dmem
(
	.clk(clk),

	.cpu_mem_op(dcache_mem_op),

	// CPU address port
	.cpu_addr_valid(d_cacheable),
	.cpu_addr(dcache_addr),

	// CPU data write port
	.cpu_write_data_valid(d_data_valid),
	.cpu_write_data(d_write_data),

	// CPU data read port
	.cpu_read_data_ready(d_data_ready),
	.cpu_read_data(d_read_data),

	// External address port
	.mem_addr_valid(dcache_ext_addr_valid),
	.mem_addr(dcache_ext_addr),

	// External data write port
	.mem_write_data_valid(dcache_ext_data_valid),
	.mem_write_data(dcache_ext_write_data),

	// External data read port
	.mem_read_data_ready(dcache_ext_data_ready),
	.mem_read_data(dcache_ext_read_data)
);

endmodule
