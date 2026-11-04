`timescale 1ps / 1ps

/* Module: mem_subsys
* Abstract away the reordering and caching specifics of the LSU, arbiter, cache,
* etc. The goal is to present the core pipeline an interface that is guaranteed
* to correctly service all load requests, regardless of how long it might take.
* Ideally it should also respond favorably to flushes. Also, present TOP with
* a stupid simple main memory interface.
*/

module mem_subsys
import rv32::*;
#(
        parameter int LINE_WIDTH = 64
)(
	input clk,
	input rst,

	// === Core pipeline interfaces === 
	// Dispatch interface
        input dispatch,
        input [5:0] dispatch_tag,
        input [6:0] new_prd,
        input ctrl_t ctrl_word,

        // Issue interface
        input issue,
        input [5:0] issue_tag,
        input [31:0] rs1_val,
        input [31:0] rs2_val,
        input [31:0] imm,

        // CDB interface (loads only)
        output logic update,
        output logic [5:0] update_tag,
        output logic [6:0] update_prd,
        output logic [31:0] update_data,

        // Commit interface (stores only)
        input commit,
        input commit_store,

	output full
);

initial begin
        $dumpfile("mem_subsys.vcd");
        $dumpvars(0, mem_subsys);
end


// DMEM load interface
logic ld_en;
logic [31:0] ld_addr;
logic ld_ready;
logic [31:0] ld_data;

// DMEM store interface
logic st_en;
store_funct3_e st_op;
logic [31:0] st_addr;
logic [31:0] st_data;

// Dcache interface
logic [31:0] d_addr;
logic [31:0] d_data_wr;
logic d_valid;
logic d_we;

lsu lsu (
	.*,
	.mem_valid(d_valid),
	.mem_we(d_we),
	.mem_addr(d_addr),
	.mem_data_o(d_data_wr)
);

dmem dmem (
	.*,
	.addr(d_addr),
	.data_o(ld_data[7:0]),
	.cs(d_valid),
	.we(d_we),
	.data_i(d_data_wr[7:0])
);

always_ff @(posedge clk, posedge rst)
begin
	if (rst) begin
		ld_ready <= 0;
	end else begin
		ld_ready <= d_valid & ~d_we;
	end
end

endmodule: mem_subsys
