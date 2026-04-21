module riscv_cpu
(
	input	wire		clk,
	input	wire		rst,

	input	wire		irq,
        output  wire            irq_ack,

        input   wire    [7:0]   serial_i,
        output  wire    [7:0]   serial_o
);

wire i_addr_valid;
wire [31:0] i_addr;
wire [31:0] i_data;
wire d_addr_valid;
wire [31:0] d_addr;
wire [31:0] d_read_data;
wire d_data_valid;
wire [31:0] d_write_data;
wire [3:0] d_mem_mask;
wire timer_irq = 0;

riscv_hart hart0
(
	.clk(clk),
	.rst(rst),

	// Icache port
	.i_addr_valid(i_addr_valid),
	.i_addr(i_addr),

	.i_data_ready(i_addr_valid),
	.i_data(i_data),

	// Dcache port
	.d_mem_mask(d_mem_mask),

	.d_addr_valid(d_addr_valid),
	.d_addr(d_addr),

	.d_data_ready(d_data_ready),
	.d_read_data(d_read_data),

	.d_data_valid(d_data_valid),
	.d_write_data(d_write_data),

	// Interrupt port
	.hardware_irq(irq),
        .hardware_irq_ack(irq_ack),
	.timer_irq(timer_irq)
);

rom imem (
        .cs(i_addr_valid & (i_addr[31:15] == 0)),
        .addr(i_addr[14:0]),

        .data(i_data)
);

ram dmem (
        .clk(clk),

        .cs(d_addr_valid & (d_addr[31:14] == 2)),
        .we(d_data_valid),
        .mask(d_mem_mask),
        
        .addr(d_addr[13:0]),

        .data_i(d_write_data),
        .data_o(d_read_data)
);

reg [7:0] uart;

always @(posedge clk) begin
        if (irq) begin
                uart <= serial_i;
        end
end

wire uart_select = d_addr_valid & d_addr == 32'hc00f;

wire d_data_ready = (uart_select & ~d_data_valid) ? 1 : d_addr_valid;
assign d_read_data = (uart_select & ~d_data_valid) ? {24'b0, uart} : 32'bz;

assign serial_o = (uart_select & d_data_valid) ? d_write_data[7:0] : 8'bz;

endmodule
