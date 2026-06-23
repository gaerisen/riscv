`timescale 1ps / 1ps

module issue
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE)
)(
        input clk,
        input rst,

        global_ctrl_ifc.decode ctrl_ifc,

        fet_to_dec_ifc.decode fet_dec_ifc,

        // Broadcasted so PRF can update ready flags
        output logic [PRF_BITS-1:0] prd_new,

        reserv_ifc.decode reserv_ifc,
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

assign instr = fet_dec_ifc.instr;
decoder decoder (.*);

// Get register aliases
logic [4:0] rs1;
logic [4:0] rs2;
logic [PRF_BITS-1:0] prs1;
logic [PRF_BITS-1:0] prs2;
logic [PRF_BITS-1:0] prd_old;

assign rs1 = instr.r.rs1;
assign rs2 = instr.r.rs2;

rat rat_ (
        .*,

        .flush(ctrl_ifc.flush),
        .rat_flush(ctrl_ifc.rat),

        .commit(commit_ifc.commit),
        .free_prd(commit_ifc.dest_old)
);

always_comb
begin
        issue_next = fet_dec_ifc.valid;

        if (ctrl_ifc.stall) begin
                issue_next = 0;
        end
end

always_comb
begin
        if (rst) begin
                reserv_ifc.issue = 0;
                reserv_ifc.ctrl_word = 0;
                reserv_ifc.pc = 0;
                reserv_ifc.imm = 0;
                reserv_ifc.prs1 = 0;
                reserv_ifc.prs2 = 0;
                reserv_ifc.prd_old = 0;
                reserv_ifc.prd_new = 0;
                reserv_ifc.speculation_meta = 0;
        end
        else begin
                reserv_ifc.issue = issue_next;
                reserv_ifc.ctrl_word = ctrl_word;
                reserv_ifc.pc = fet_dec_ifc.pc;
                reserv_ifc.imm = imm;
                reserv_ifc.prs1 = prs1;
                reserv_ifc.prs2 = prs2;
                reserv_ifc.prd_old = prd_old;
                reserv_ifc.prd_new = prd_new;
                reserv_ifc.speculation_meta = fet_dec_ifc.speculation_meta;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                issue_ifc.issue <= 0;
                issue_ifc.ctrl_word <= 0;
                issue_ifc.pc <= 0;
                issue_ifc.imm <= 0;
                issue_ifc.prs1 <= 0;
                issue_ifc.prs2 <= 0;
                issue_ifc.prd_old <= 0;
                issue_ifc.prd_new <= 0;
                issue_ifc.speculation_meta <= 0;
                issue_ifc.rat <= 0;
        end
        else begin
                issue_ifc.issue <= issue_next;
                issue_ifc.ctrl_word <= ctrl_word;
                issue_ifc.pc <= fet_dec_ifc.pc;
                issue_ifc.imm <= imm;
                issue_ifc.prs1 <= prs1;
                issue_ifc.prs2 <= prs2;
                issue_ifc.prd_old <= prd_old;
                issue_ifc.prd_new <= prd_new;
                issue_ifc.speculation_meta <= fet_dec_ifc.speculation_meta;
                issue_ifc.rat <= rat;
        end
end

endmodule: issue
