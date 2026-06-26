`timescale 1ps / 1ps
module execute
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE)
)(
        input clk,
        input rst,

        dispatch_ifc.execute dispatch_ifc,

        global_ctrl_ifc.execute ctrl_ifc,

        cdb_ifc.execute cdb_ifc
);

logic [31:0] alu_result;
logic [31:0] csr_result;
logic branch_taken;
logic ready_exe_next;
logic [31:0] result_exe_next;
logic [PRF_BITS-1:0] rd_exe_next;
logic [31:0] alu_in1;
logic [31:0] alu_in2;

always_comb
begin
        unique case(dispatch_ifc.ctrl_word.alu_src)
        REG_REG: begin
                if (dispatch_ifc.ctrl_word.branch) begin
                        alu_in1 = dispatch_ifc.pc;
                        alu_in2 = dispatch_ifc.imm;
                end
                else if (dispatch_ifc.ctrl_word.store) begin
                        alu_in1 = dispatch_ifc.rs1_val;
                        alu_in2 = dispatch_ifc.imm;
                end
                else begin
                        alu_in1 = dispatch_ifc.rs1_val;
                        alu_in2 = dispatch_ifc.rs2_val;
                end
        end
        REG_IMM: begin
                alu_in1 = dispatch_ifc.rs1_val;
                alu_in2 = dispatch_ifc.imm;
        end
        ZERO_IMM: begin
                alu_in1 = 0;
                alu_in2 = dispatch_ifc.imm;
        end
        PC_IMM: begin
                alu_in1 = dispatch_ifc.pc;
                alu_in2 = dispatch_ifc.imm;
        end
        endcase
end


// Ex unit for integral arithmetic and logic instructions
alu alu (
        .*,

        .in1(alu_in1),
        .in2(alu_in2),

        .op(dispatch_ifc.ctrl_word.alu_op),
        .alt(dispatch_ifc.ctrl_word.alu_alt),

        .result(alu_result)
);

// Ex unit for branch resolution
bu bu (
        .*,

        .rs1_val(dispatch_ifc.rs1_val),
        .rs2_val(dispatch_ifc.rs2_val),

        .op(dispatch_ifc.ctrl_word.branch_op),

        .result(branch_taken)
);

// Ex unit for Zicsr instructions
csru csru (
        .*,

        .rs1_val(dispatch_ifc.rs1_val),

        .op(dispatch_ifc.ctrl_word.csr_op),
        .src(dispatch_ifc.ctrl_word.csr_src),

        .imm(dispatch_ifc.imm),

        .csr_old(0),

        .csr_new(csr_result)
);

always_comb
begin
        ready_exe_next = 0;
        result_exe_next = 0;
        rd_exe_next = dispatch_ifc.prd_new;

        if (!ctrl_ifc.flush) begin
                ready_exe_next = dispatch_ifc.dispatch;

        end

        unique case (dispatch_ifc.ctrl_word.wb_src)
        WB_ALU: begin // Decoder lets default value thru for stores
                if (dispatch_ifc.ctrl_word.store) begin
                        result_exe_next = dispatch_ifc.rs2_val;
                end
                else
                        result_exe_next = alu_result;
        end
        WB_MEM: result_exe_next = 0; // TODO: Come on, bro
        WB_PC4: result_exe_next = dispatch_ifc.pc + 32'h4;
        WB_CSR: result_exe_next = 0;
        endcase
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                cdb_ifc.update <= 0;
                cdb_ifc.dest <= 0;
                cdb_ifc.dest_old <= 0;
                cdb_ifc.value <= 0;
                cdb_ifc.tag <= 0;

                ctrl_ifc.branch_pc <= 0;
                ctrl_ifc.speculation_meta <= 0;
                ctrl_ifc.tag <= 0;
                ctrl_ifc.branch_result_ready <= 0;
                ctrl_ifc.branch_taken <= 0;
                ctrl_ifc.branch_target <= 0;
                cdb_ifc.speculation_meta <= 0;
                cdb_ifc.branch_taken <= 0;
        end
        else begin
                cdb_ifc.update <= ready_exe_next;
                cdb_ifc.dest <= rd_exe_next;
                cdb_ifc.dest_old <= dispatch_ifc.prd_old;
                cdb_ifc.value <= result_exe_next;
                cdb_ifc.tag <= dispatch_ifc.tag;
                cdb_ifc.speculation_meta <= dispatch_ifc.speculation_meta;
                cdb_ifc.branch_taken <= branch_taken;

                ctrl_ifc.branch_pc <= dispatch_ifc.pc;
                ctrl_ifc.speculation_meta <= dispatch_ifc.speculation_meta;
                ctrl_ifc.tag <= dispatch_ifc.tag;
                ctrl_ifc.branch_result_ready <= ready_exe_next;
                ctrl_ifc.branch_taken <= branch_taken;
                ctrl_ifc.branch_target <= alu_result;
        end
end

endmodule
