module top (
        input   wire            clock,
        input   wire            reset,

        input   wire            irq,
        output  wire            irq_ack,

        input   wire    [7:0]   serial_input,
        output  wire    [7:0]   serial_output
);

/* initial
begin
	$dumpfile("wave.vcd");
	$dumpvars(0, top);
end */

assign serial_output = 8'bz;

riscv_cpu cpu
(
	.clk(clock),
	.rst(reset),

	.irq(irq),
        .irq_ack(irq_ack),

        .serial_i(serial_input),
        .serial_o(serial_output)
);

endmodule
