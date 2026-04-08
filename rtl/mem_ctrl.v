module mem_ctrl
(
        input   wire            clk,

	input	wire		addr_valid,
	input	wire	[31:0]	addr,

        input   wire            write_enable,
        input   wire    [511:0] data_i,

	output	reg		data_ready,
	output	wire	[511:0]	data_o,
        output  reg     [31:0]  data_ready_addr
);

always @(posedge clk)
begin
        data_ready <= addr_valid;
        data_ready_addr <= addr;
end

wire select_flash = addr[31:15] == 0;
wire select_ram = addr[31:14] == 2;

wire [511:0] flash_data_r;
wire [511:0] ram_data_r;

assign data_o = select_flash ? flash_data_r :
                select_ram ? ram_data_r :
                512'bz;

rom flash (
        .clk(clk),

        .addr(addr[14:0]),

        .data(flash_data_r)
);

ram ram (
        .clk(clk),
        
        .write_enable(write_enable),

        .addr(addr[13:0]),

        .data_i(data_i),

        .data_o(ram_data_r)
);

endmodule
