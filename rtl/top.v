module top ();

reg	clock;
reg	mem_clock;
reg	reset;
reg	rtc_clk;
reg	rtc_dly;

initial
begin
	clock = 0;
	mem_clock = 0;
	reset = 0;

	$dumpfile("wave.vcd");
	$dumpvars(0, top);
end

always #10
	clock <= !clock;

always #100
	mem_clock <= !mem_clock;

always #320
	rtc_clk <= !rtc_clk;

always @(posedge clock)
begin
	rtc_dly <= rtc_clk;
end

wire		rtc;
wire		addr_valid;
wire	[31:0]	addr;
wire		write_data_valid;
wire	[511:0]	write_data;
wire		read_data_ready;
wire	[511:0]	read_data;
wire    [31:0]  read_data_ready_addr;

assign rtc = rtc_clk ^ rtc_dly;

riscv_cpu cpu
(
	.clk(clock),
	.rst(reset),

	.ext_addr_valid(addr_valid),
	.ext_addr(addr),

	.ext_write_data_valid(write_data_valid),
	.ext_write_data(write_data),

	.ext_read_data_ready(read_data_ready),
	.ext_read_data(read_data),
        .ext_read_data_ready_addr(read_data_ready_addr),

	.ext_timer_tick(rtc),

	.ext_irq(0)
);

mem_ctrl mem_ctrl (
        .clk(mem_clock),

        .addr_valid(addr_valid),
        .addr(addr),

        .write_enable(write_data_valid),
        .data_i(write_data),

        .data_ready(read_data_ready),
        .data_o(read_data),
        .data_ready_addr(read_data_ready_addr)
);


endmodule
