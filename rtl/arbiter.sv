`timescale 1ps / 1ps

/** Module: Arbiter
* Function: Arbitrate load and store requests from LSU so there aren't
* collisions on the internal data bus
*/

module arbiter
import rv32::*;
#(
)(
        input clk,
        input rst,

        // LSU load interface
        input logic ld_en,
        input logic [31:0] ld_addr,
        output logic ld_ready,
        output logic [31:0] ld_data,

        // LSU store interface
        input logic st_en,
        input store_funct3_e st_op,
        input logic [31:0] st_addr,
        input logic [31:0] st_data,

	// Dcache interface
	output logic [31:0] d_addr,
	output logic [31:0] d_data_o,
	output logic d_valid,
	output logic d_we,
	output store_funct3_e d_st_op,

	input logic [31:0] d_data_i,
	input logic d_ready
);

initial begin
        $dumpfile("arbiter.vcd");
        $dumpvars(0, arbiter);
end

logic pref_st;
logic pref_st_next;

logic do_ld;
logic do_st;
logic clash;

logic ld_ready_next;
logic [31:0] ld_data_next;
logic [31:0] d_addr_next;
logic [31:0] d_data_o_next;
logic d_valid_next;
logic d_we_next;
store_funct3_e d_st_op_next;

always_comb
begin
	d_valid_next = st_en | ld_en;
	clash = st_en & ld_en;
	pref_st_next = pref_st;

	if (clash) begin
		pref_st_next = ~pref_st;
	end

	do_ld = ld_en & ~(st_en & pref_st);
	do_st = st_en & (~ld_en | pref_st);

	if (do_ld) begin
		d_addr_next = ld_addr;
		d_data_o_next = 0;
		d_st_op_next = SB;
		d_we_next = 0;
		ld_ready_next = d_ready;
		ld_data_next = d_data_i;
	end else if (do_st) begin
		d_addr_next = st_addr;
		d_data_o_next = st_data;
		d_st_op_next = st_op;
		d_we_next = 1;
		ld_ready_next = 0;
		ld_data_next = 0;
	end else begin
		d_addr_next = 0;
		d_data_o_next = 0;
		d_st_op_next = SB;
		d_we_next = 0;
		ld_ready_next = 0;
		ld_data_next = 0;
	end
end

always_ff @(posedge clk or posedge rst)
begin
	if (rst) begin
		pref_st <= 0;
		ld_ready <= 0;
		ld_data <= 0;
		d_addr <= 0;
		d_data_o <= 0;
		d_valid <= 0;
		d_we <= 0;
		d_st_op <= SB;
	end else begin
		pref_st <= pref_st_next;
		ld_ready <= ld_ready_next;
		ld_data <= ld_data_next;
		d_addr <= d_addr_next;
		d_data_o <= d_data_o_next;
		d_valid <= d_valid_next;
		d_we <= d_we_next;
		d_st_op <= d_st_op_next;
	end
end

endmodule: arbiter
