module top ();

reg	clock;
reg	mem_clock;
reg	reset;
reg	rtc_clk;
reg	rtc_dly;

initial
begin
	clock = 1;
	mem_clock = 1;
	reset = 0;

	$dumpfile("wave.vcd");
	$dumpvars(0, top);
end

always #10
	clock <= !clock;

always #40
	mem_clock <= !mem_clock;

always #320
	rtc_clk <= !rtc_clk;

always @(posedge clock)
begin
	rtc_dly <= rtc_clk;
end

wire		rtc;
wire	[31:0]	addr;
wire            write_enable;
wire	[63:0]	write_data;
wire	[63:0]	read_data;

assign rtc = rtc_clk ^ rtc_dly;

riscv_cpu cpu
(
	.clk(clock),
	.rst(reset),

	.addr(addr),

        .write_enable(write_enable),
	.write_data(write_data),
	.read_data(read_data),

	.irq(0)
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
