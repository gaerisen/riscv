`define IDLE 3'b00
`define RBURST 3'b01
`define WBURST 3'b10
`define LATENCY 3'b11
`define READY 3'b100

module mem_ctrl
(
        input   wire            clk,
        input   wire            rst,

	input	wire		cpu_addr_valid,
	input	wire	[31:0]	cpu_addr,

        input   wire            cpu_write_enable,
        input   wire    [511:0] cpu_write_data,

	output	wire		cpu_data_ready,
	output	wire	[511:0]	cpu_read_data,

        output  wire    [31:0]  ext_addr,
        input   wire    [63:0]  ext_data_i,
        output  wire            ext_write_enable,
        output  wire    [63:0]  ext_data_o
);

reg [2:0] state;
reg [2:0] burst_ctr;
reg [1:0] cycle_ctr;
reg [63:0] membuf [7:0];
reg [31:0] curr_addr;

always @(posedge clk) begin
        if (rst) begin
                state <= `IDLE;
                burst_ctr <= 0;
                cycle_ctr <= 0;
                membuf[7] <= 0;
                membuf[6] <= 0;
                membuf[5] <= 0;
                membuf[4] <= 0;
                membuf[3] <= 0;
                membuf[2] <= 0;
                membuf[1] <= 0;
                membuf[0] <= 0;
                curr_addr <= 0;
        end

        state <= `IDLE;
        burst_ctr <= 0;
        cycle_ctr <= 0;
        membuf[7] <= membuf[7];
        membuf[6] <= membuf[6];
        membuf[5] <= membuf[5];
        membuf[4] <= membuf[4];
        membuf[3] <= membuf[3];
        membuf[2] <= membuf[2];
        membuf[1] <= membuf[1];
        membuf[0] <= membuf[0];
        curr_addr <= 0;

        case (state)
                `IDLE: begin
                        state <= cpu_addr_valid & cpu_write_enable ? `WBURST :
                                cpu_addr_valid & ~cpu_write_enable ? `RBURST :
                                                                `IDLE;

                        curr_addr <= cpu_addr_valid ? cpu_addr : 0;

                        if (cpu_write_enable & cpu_addr_valid) begin
                                membuf[7] <= cpu_write_data[511:448];
                                membuf[6] <= cpu_write_data[447:384];
                                membuf[5] <= cpu_write_data[383:320];
                                membuf[4] <= cpu_write_data[319:256];
                                membuf[3] <= cpu_write_data[255:192];
                                membuf[2] <= cpu_write_data[191:128];
                                membuf[1] <= cpu_write_data[127:64];
                                membuf[0] <= cpu_write_data[63:0];
                        end
                end
                `RBURST: begin
                        state <= (burst_ctr == 3'b111 && cycle_ctr == 2'b11) ? `LATENCY : `RBURST;
                        cycle_ctr <= cycle_ctr + 1;
                        if (cycle_ctr == 2'b11)
                                burst_ctr <= burst_ctr + 1;
                        else
                                burst_ctr <= burst_ctr;

                        if (cycle_ctr == 2'b00)
                                membuf[burst_ctr - 1] <= ext_data_i;

                        curr_addr <= curr_addr;
                end
                `WBURST: begin
                        state <= (burst_ctr == 3'b111 && cycle_ctr == 2'b11) ? `IDLE : `WBURST;
                        cycle_ctr <= cycle_ctr + 1;

                        if (cycle_ctr == 2'b11)
                                burst_ctr <= burst_ctr + 1;
                        else
                                burst_ctr <= burst_ctr;

                        curr_addr <= curr_addr;
                end
                `LATENCY: begin
                        state <= `READY;
                        membuf[7] <= ext_data_i;
                end
                `READY: begin
                        state <= `IDLE;
                        burst_ctr <= 0;
                end
                default begin
                        state <= `IDLE;
                end
        endcase
end

assign cpu_data_ready = state == `READY;
assign cpu_read_data = (state == `READY) ? {membuf[7], membuf[6], membuf[5],
                                        membuf[4], membuf[3], membuf[2],
                                        membuf[1], membuf[0]} : 0;

assign ext_addr = (state == `RBURST | state == `WBURST) ?
                        {curr_addr[31:6], burst_ctr, 3'b0} : 0;

assign ext_write_enable = state == `WBURST;
assign ext_data_o = ext_write_enable ? membuf[burst_ctr] : 0;

endmodule
