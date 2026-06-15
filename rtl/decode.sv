`timescale 1ps / 1ps

module decode
import rv32::*;
#(
)(
        input clk,
        input rst,

        global_ctrl_ifc.decode ctrl_ifc,

        fet_to_dec_ifc.decode fet_dec_ifc,

        fwding_ifc.decode fwd_ifc,

        issue_ifc.decode issue_ifc
);

instr_t instr;
ctrl_t ctrl_word;
logic [31:0] imm;
logic [4:0] rd;
logic issue_next;

// Pack raw instruction into union struct
assign instr = fet_dec_ifc.instr;

decoder decoder (
        .*
);

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
                issue_ifc.ctrl_word <= 0;
                issue_ifc.pc <= 0;
                issue_ifc.imm <= 0;
                issue_ifc.csr_val <= 0;
                issue_ifc.rd <= 0;
                issue_ifc.csrs <= 0;
                issue_ifc.speculation_meta <= 0;

                fwd_ifc.rs1 <= 0;
                fwd_ifc.rs1_val <= 0;
                fwd_ifc.rs2 <= 0;
                fwd_ifc.rs2_val <= 0;
        end
        else begin
                issue_ifc.issue <= issue_next;
                issue_ifc.ctrl_word <= ctrl_word;
                issue_ifc.pc <= fet_dec_ifc.pc;
                issue_ifc.imm <= imm;
                issue_ifc.csr_val <= fet_dec_ifc.csr_val;
                issue_ifc.rd <= rd;
                issue_ifc.csrs <= fet_dec_ifc.csrs;
                issue_ifc.speculation_meta <= fet_dec_ifc.speculation_meta;

                fwd_ifc.rs1 <= fet_dec_ifc.rs1;
                fwd_ifc.rs1_val <= fet_dec_ifc.rs1_val;
                fwd_ifc.rs2 <= fet_dec_ifc.rs2;
                fwd_ifc.rs2_val <= fet_dec_ifc.rs2_val;
        end
end

endmodule: decode
