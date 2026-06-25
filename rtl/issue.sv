`timescale 1ps / 1ps

module issue
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        localparam int FREE_SIZE = PRF_SIZE - 32,
        localparam int FREE_BITS = $clog2(FREE_SIZE)
)(
        input clk,
        input rst,

        global_ctrl_ifc.decode ctrl_ifc,

        fet_to_dec_ifc.decode fet_dec_ifc,

        // Broadcasted so PRF can update ready flags
        output logic [PRF_BITS-1:0] prd_new,

        issue_ifc.decode issue_ifc,

        commit_ifc.decode commit_ifc
);

// Decode instruction word
instr_t instr;
ctrl_t ctrl_word;
logic [31:0] imm;
logic [4:0] rd;
logic issue_next;

logic [31:0][PRF_BITS-1:0] rat;
logic [31:0][PRF_BITS-1:0] rat_next;
logic [FREE_SIZE-1:0][PRF_BITS-1:0] free_list;
logic [FREE_BITS-1:0] free_head;
logic [FREE_BITS-1:0] free_tail;
logic [FREE_BITS-1:0] free_head_next;
logic [FREE_BITS-1:0] free_tail_next;
logic [PRF_BITS-1:0] free_push_next;

logic [4:0] rs1;
logic [4:0] rs2;
logic [PRF_BITS-1:0] prs1;
logic [PRF_BITS-1:0] prs2;
logic [PRF_BITS-1:0] prd_old;

// ==========
//   Decode
// ==========
assign instr = fet_dec_ifc.instr;
assign rs1 = instr.r.rs1;
assign rs2 = instr.r.rs2;
decoder decoder (.*);


// ==========
//   Rename
// ==========
assign prs1 = rat[rs1];
assign prs2 = rat[rs2];
assign prd_old = rat[rd];

always_comb
begin
        if (ctrl_ifc.flush) begin
                free_head_next = ctrl_ifc.free_head;
                rat_next = ctrl_ifc.rat;
        end
        else begin
                free_head_next = free_head;
                rat_next = rat;
        end

        free_tail_next = free_tail;
        free_push_next = free_list[free_tail];
        prd_new = 0;


        if ((rd != 0) & issue_next) begin
                if (ctrl_ifc.flush) begin
                        free_head_next = ctrl_ifc.free_head + 1;
                        prd_new = free_list[ctrl_ifc.free_head];
                end
                else begin
                        free_head_next = free_head + 1;
                        prd_new = free_list[free_head];
                end
                rat_next[rd] = prd_new;
        end

        if (commit_ifc.commit && commit_ifc.dest_old != 0) begin
                free_tail_next = free_tail + 1;
                free_push_next = commit_ifc.dest_old;
        end

end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < 32; i++) begin
                        rat[i] <= i[5:0];
                end
                for (int i = 0; i < PRF_SIZE - 32; i++) begin
                        free_list[i] <= i[5:0] + 32;
                end
                free_head <= 0;
                free_tail <= 0;
        end
        else begin
                rat <= rat_next;
                free_list[free_tail] <= free_push_next;
                free_head <= free_head_next;
                free_tail <= free_tail_next;
        end
end


// ============
//   Dispatch
// ============
always_comb
begin
        issue_next = fet_dec_ifc.valid;

        if (ctrl_ifc.stall) begin
                issue_next = 0;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                issue_ifc.issue <= 0;
        end
        else begin
                issue_ifc.issue <= issue_next;
        end

        if (rst) begin
                issue_ifc.ctrl_word <= 0;
                issue_ifc.pc <= 0;
                issue_ifc.imm <= 0;
                issue_ifc.prs1 <= 0;
                issue_ifc.prs2 <= 0;
                issue_ifc.prd_old <= 0;
                issue_ifc.prd_new <= 0;
                issue_ifc.speculation_meta <= 0;
                issue_ifc.rat <= 0;
                issue_ifc.free_list <= 0;
                issue_ifc.free_head <= 0;
                issue_ifc.free_tail <= 0;
        end
        else if (issue_next) begin
                issue_ifc.ctrl_word <= ctrl_word;
                issue_ifc.pc <= fet_dec_ifc.pc;
                issue_ifc.imm <= imm;
                issue_ifc.prs1 <= prs1;
                issue_ifc.prs2 <= prs2;
                issue_ifc.prd_old <= prd_old;
                issue_ifc.prd_new <= prd_new;
                issue_ifc.speculation_meta <= fet_dec_ifc.speculation_meta;
                issue_ifc.rat <= rat;
                issue_ifc.free_list <= free_list;
                issue_ifc.free_head <= free_head;
                issue_ifc.free_tail <= free_tail;
        end
end

endmodule: issue
