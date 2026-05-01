module top (
`ifdef DEBUG
        output  wire    [31:0]  pc_dbg,
        output  wire    [31:0]  sp_dbg,

        output  wire            trap_dbg,
        output  wire            mret_dbg,
        output  wire            jump_dbg,
`endif
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
`ifdef DEBUG
        .pc_dbg(pc_dbg),
        .sp_dbg(sp_dbg),
        .trap_dbg(trap_dbg),
        .mret_dbg(mret_dbg),
        .jump_dbg(jump_dbg),
`endif
	.clk(clock),
	.rst(reset),

	.irq(irq),
        .irq_ack(irq_ack),

        .serial_i(serial_input),
        .serial_o(serial_output)
);

endmodule
