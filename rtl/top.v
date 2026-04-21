module top (
        input   wire            clock,
        input   wire            reset,

        input   wire            irq,
        output  wire            irq_ack,

        input   wire    [7:0]   serial_input,
        output  wire    [7:0]   serial_output
);

reg     [1:0]   mem_ctr;
wire mem_clock = mem_ctr[1];
reg	rtc_clk;
reg	rtc_dly;

initial
begin
	$dumpfile("wave.vcd");
	$dumpvars(0, top);
end

always @(posedge clock)
begin
        mem_ctr <= mem_ctr + 1;
	rtc_dly <= rtc_clk;
end

wire		rtc;
wire	[31:0]	addr;
wire            write_enable;
wire	[63:0]	write_data;
wire	[63:0]	read_data;

assign rtc = rtc_clk ^ rtc_dly;

assign serial_output = 8'bz;

riscv_cpu cpu
(
	.clk(clock),
	.rst(reset),

	.addr(addr),

        .write_enable(write_enable),
	.write_data(write_data),
	.read_data(read_data),

	.irq(irq),
        .irq_ack(irq_ack),

        .serial_i(serial_input),
        .serial_o(serial_output)
);

rom rom (
        .clk(mem_clock),

        .cs(addr[31:15] == 0),

        .addr(addr[14:0]),
        .data(read_data)
);

ram ram (
        .clk(mem_clock),

        .cs(addr[31:14] == 18'b10),
        .we(write_enable),

        .addr(addr[13:0]),

        .data_i(write_data),
        .data_o(read_data)
);

endmodule
