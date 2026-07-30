`timescale 1ps / 1ps
module execute
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE)
)(
        input clk,
        input rst,

        issue_ifc.execute issue_ifc,

        cdb_ifc.execute cdb_ifc
);

logic [31:0] alu_result;
logic [31:0] csr_result;
logic branch_taken;
logic [31:0] result_exe_next;
logic [PRF_BITS-1:0] rd_exe_next;
logic [31:0] alu_in1;
logic [31:0] alu_in2;

always_comb
begin
        unique case(issue_ifc.ctrl_word.alu_src)
        REG_REG: begin
                if (issue_ifc.ctrl_word.branch) begin
                        alu_in1 = issue_ifc.pc;
                        alu_in2 = issue_ifc.imm;
                end
                else if (issue_ifc.ctrl_word.store) begin
                        alu_in1 = issue_ifc.rs1_val;
                        alu_in2 = issue_ifc.imm;
                end
                else begin
                        alu_in1 = issue_ifc.rs1_val;
                        alu_in2 = issue_ifc.rs2_val;
                end
        end
        REG_IMM: begin
                alu_in1 = issue_ifc.rs1_val;
                alu_in2 = issue_ifc.imm;
        end
        ZERO_IMM: begin
                alu_in1 = 0;
                alu_in2 = issue_ifc.imm;
        end
        PC_IMM: begin
                alu_in1 = issue_ifc.pc;
                alu_in2 = issue_ifc.imm;
        end
        endcase
end


// Ex unit for integral arithmetic and logic instructions
alu alu (
        .*,

        .in1(alu_in1),
        .in2(alu_in2),

        .op(issue_ifc.ctrl_word.alu_op),
        .alt(issue_ifc.ctrl_word.alu_alt),

        .result(alu_result)
);

// Ex unit for branch resolution
bu bu (
        .*,

        .rs1_val(issue_ifc.rs1_val),
        .rs2_val(issue_ifc.rs2_val),

        .op(issue_ifc.ctrl_word.branch_op),

        .result(branch_taken)
);

// Ex unit for Zicsr instructions
csru csru (
        .*,

        .rs1_val(issue_ifc.rs1_val),

        .op(issue_ifc.ctrl_word.csr_op),
        .src(issue_ifc.ctrl_word.csr_src),

        .imm(issue_ifc.imm),

        .csr_old(0),

        .csr_new(csr_result)
);

logic update_next;

always_comb
begin
        result_exe_next = 0;
        rd_exe_next = issue_ifc.prd_new;

        unique case (issue_ifc.ctrl_word.wb_src)
        WB_ALU: begin // Decoder lets default value thru for stores
                if (issue_ifc.ctrl_word.store) begin
                        result_exe_next = issue_ifc.rs2_val;
                end
                else
                        result_exe_next = alu_result;
        end
        WB_MEM: result_exe_next = 0;
        WB_PC4: result_exe_next = issue_ifc.pc + 32'h4;
        WB_CSR: result_exe_next = issue_ifc.csr_val;
        endcase

        // Reject loads and stores; those will come out of the LSU
        update_next = issue_ifc.issue & issue_ifc.ctrl_word[36:35] == 0;
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                cdb_ifc.update <= 0;
                cdb_ifc.valid <= 0;
                cdb_ifc.dest <= 0;
                cdb_ifc.dest_old <= 0;
                cdb_ifc.csrd <= 0;
                cdb_ifc.csr_result <= 0;
                cdb_ifc.value <= 0;
                cdb_ifc.tag <= 0;
                cdb_ifc.branch_taken <= 0;
                cdb_ifc.pc <= 0;
                cdb_ifc.target_addr <= 0;
        end
        else begin
                cdb_ifc.update <= update_next;
                cdb_ifc.valid <= issue_ifc.valid;
                cdb_ifc.dest <= rd_exe_next;
                cdb_ifc.dest_old <= issue_ifc.prd_old;
                cdb_ifc.csrd <= issue_ifc.csrd;
                cdb_ifc.csr_result <= csr_result;
                cdb_ifc.value <= result_exe_next;
                cdb_ifc.tag <= issue_ifc.tag;
                cdb_ifc.branch_taken <= branch_taken;
                cdb_ifc.pc <= issue_ifc.pc;
                cdb_ifc.target_addr <= alu_result; // Technically redundant for
                                                // branches, but nice for jumps
                                                // and stores
        end
end

endmodule
