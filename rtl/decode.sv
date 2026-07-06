`timescale 1ps / 1ps

module decode 
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        localparam int FREE_SIZE = PRF_SIZE,
        localparam int FREE_BITS = $clog2(FREE_SIZE)
)(
        input clk,
        input rst,

        global_ctrl_ifc.decode ctrl_ifc,

        fet_to_dec_ifc.decode fet_dec_ifc,

        dispatch_ifc.decode dispatch_ifc,

        cdb_ifc.decode cdb_ifc,

        commit_ifc.decode commit_ifc
);

// Decode instruction word
instr_t instr;
ctrl_t ctrl_word;
logic [31:0] imm;
logic [4:0] rd;
logic dispatch_next /* verilator public */;
logic [31:0] spec_mask_next;
logic [31:0] spec_mask;

logic [31:0][PRF_BITS-1:0] rat /* verilator public */;
logic [FREE_SIZE-1:0][PRF_BITS-1:0] free_list /* verilator public */;
logic [FREE_BITS-1:0] free_head /* verilator public */;
logic [FREE_BITS-1:0] free_tail /* verilator public */;
logic [31:0][PRF_BITS-1:0] rat_next;
logic [FREE_SIZE-1:0][PRF_BITS-1:0] free_list_next;
logic [FREE_BITS-1:0] free_head_next;
logic [FREE_BITS-1:0] free_tail_next;

logic [4:0] rs1;
logic [4:0] rs2;
logic [11:0] csrs;
logic [PRF_BITS-1:0] prs1;
logic [PRF_BITS-1:0] prs2;
logic [PRF_BITS-1:0] prd_old;
logic [PRF_BITS-1:0] prd_new;

// ==========
//   Decode
// ==========
assign instr = fet_dec_ifc.instr;
assign rs1 = instr.r.rs1;
assign rs2 = instr.r.rs2;
assign csrs = instr.i.imm11_0;

decoder decoder (.*);

always_comb
begin
        spec_mask_next = spec_mask;

        if (fet_dec_ifc.speculation_meta.branch || fet_dec_ifc.speculation_meta.jump) begin
                spec_mask_next = spec_mask + 1;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                spec_mask <= 0;
        end
        else begin
                spec_mask <= spec_mask_next;
        end
end

// ==========
//   Rename
// ==========
assign prs1 = rat[rs1];
assign prs2 = rat[rs2];
assign prd_old = rat[rd];

always_comb
begin
        rat_next = rat;
        free_tail_next = free_tail;
        free_head_next = free_head;
        free_list_next = free_list;
        prd_new = 0;

        // Issue first; should be overwritten by rollback (although this isn't
        // strictly necessary since issue_next goes low on rb)
        if ((rd != 0) & dispatch_next) begin
                free_head_next = free_head + 1;
                prd_new = free_list[free_head];
                rat_next[rd] = prd_new;
        end

        if (cdb_ifc.rollback) begin
                rat_next = cdb_ifc.rat;
                free_head_next = cdb_ifc.free_head;
        end

        // Commit should override rollback; anything committing has no control
        // dependencies
        if (commit_ifc.commit && commit_ifc.dest_old != 0) begin
                free_tail_next = free_tail + 1;
                free_list_next[free_tail] = commit_ifc.dest_old;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                int i;
                for (i = 0; i < 32; i++) begin
                        rat[i] <= i[PRF_BITS-1:0];
                end
                for (i = 0; i < PRF_SIZE - 32; i++) begin
                        free_list[i] <= i[PRF_BITS-1:0] + 32;
                end
                free_head <= 0;
                free_tail <= i[FREE_BITS-1:0];
        end
        else begin
                rat <= rat_next;
                free_list <= free_list_next;
                free_head <= free_head_next;
                free_tail <= free_tail_next;
        end
end



// ============
//   Dispatch
// ============
always_comb
begin
        dispatch_next = fet_dec_ifc.valid;

        if (ctrl_ifc.internal_stall | cdb_ifc.rollback) begin
                dispatch_next = 0;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                dispatch_ifc.dispatch <= 0;
        end
        else begin
                dispatch_ifc.dispatch <= dispatch_next;
        end

        if (rst) begin
                dispatch_ifc.ctrl_word <= 0;
                dispatch_ifc.pc <= 0;
                dispatch_ifc.imm <= 0;
                dispatch_ifc.prs1 <= 0;
                dispatch_ifc.prs2 <= 0;
                dispatch_ifc.csrs <= 0;
                dispatch_ifc.prd_old <= 0;
                dispatch_ifc.prd_new <= 0;
                dispatch_ifc.speculation_meta <= 0;
                dispatch_ifc.rat <= 0;
                dispatch_ifc.free_head <= 0;
                dispatch_ifc.spec_mask <= 0;
        end
        else if (dispatch_next) begin
                dispatch_ifc.ctrl_word <= ctrl_word;
                dispatch_ifc.pc <= fet_dec_ifc.pc;
                dispatch_ifc.imm <= imm;
                dispatch_ifc.prs1 <= prs1;
                dispatch_ifc.prs2 <= prs2;
                dispatch_ifc.csrs <= csrs;
                dispatch_ifc.prd_old <= prd_old;
                dispatch_ifc.prd_new <= prd_new;
                dispatch_ifc.speculation_meta <= fet_dec_ifc.speculation_meta;
                dispatch_ifc.rat <= rat_next;
                dispatch_ifc.free_head <= free_head_next;
                dispatch_ifc.spec_mask <= spec_mask;
        end
end

endmodule: decode 
