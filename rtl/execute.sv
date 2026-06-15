`timescale 1ps / 1ps
module execute
import rv32::*;
#(
)(
        input clk,
        input rst,

        input [31:0] pc_dec,
        input ctrl_t ctrl_dec,
        input speculation_meta_t speculation_meta_dec,
        input issue,

        input [31:0] csr_val_dec,
        input [4:0] rd_dec,

        input [31:0] imm,

        global_ctrl_ifc.execute ctrl_ifc,

        fwding_ifc.execute fwd_ifc,

        output logic [31:0] pc_exe,
        output ctrl_t ctrl_exe,
        output logic ready_exe,
        output logic [31:0] result_exe,
        output logic [31:0] csr_result_exe,
        output logic [31:0] rd_exe
);

logic [31:0] rs1_value;
logic [31:0] rs2_value;

logic [31:0] alu_result;
logic [31:0] csr_result;
logic branch_taken;
logic ready_exe_next;
logic [31:0] result_exe_next;
logic [31:0] rd_exe_next;

assign rs1_value = fwd_ifc.in1;
assign rs2_value = fwd_ifc.in2;

// Ex unit for integral arithmetic and logic instructions
alu alu (
        .*,

        .op(ctrl_dec.alu_op),
        .alt(ctrl_dec.alu_alt),
        .src1(ctrl_dec.alu_src1),
        .src2(ctrl_dec.alu_src2),

        .result(alu_result)
);

// Ex unit for branch resolution
bu bu (
        .*,

        .op(ctrl_dec.branch_op),

        .result(branch_taken)
);

// Ex unit for Zicsr instructions
csru csru (
        .*,

        .op(ctrl_dec.csr_op),
        .src(ctrl_dec.csr_src),

        .csr_old(csr_val_dec),

        .csr_new(csr_result)
);

always_comb
begin
        ready_exe_next = 0;
        result_exe_next = 0;
        rd_exe_next = {27'b0, rd_dec};

        if (!ctrl_ifc.flush) begin
                ready_exe_next = issue;
        end

        unique case (ctrl_dec.wb_src)
        WB_ALU: begin // Decoder lets default value thru for stores
                if (ctrl_dec.store) begin
                        result_exe_next = rs2_value;
                        rd_exe_next = alu_result;
                end
                else
                        result_exe_next = alu_result;
        end
        WB_MEM: result_exe_next = 0; // TODO: Come on, bro
        WB_PC4: result_exe_next = pc_dec + 4;
        WB_CSR: result_exe_next = csr_val_dec;
        endcase
end

logic exe_val_valid_next;
assign exe_val_valid_next = ready_exe_next & !ctrl_ifc.flush & ctrl_dec.irf_we;

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_exe <= 0;
                ctrl_exe <= 0;
                rd_exe <= 0;
                ready_exe <= 0;
                result_exe <= 0;
                csr_result_exe <= 0;

                ctrl_ifc.branch_pc <= 0;
                ctrl_ifc.speculation_meta <= 0;
                ctrl_ifc.branch_result_ready <= 0;
                ctrl_ifc.branch_taken <= 0;
                ctrl_ifc.branch_target <= 0;

                fwd_ifc.exe_val_valid <= 0;
                fwd_ifc.rd_exe <= 0;
                fwd_ifc.exe_val <= 0;
        end
        else begin
                pc_exe <= pc_dec;
                ctrl_exe <= ctrl_dec;
                rd_exe <= rd_exe_next;
                ready_exe <= ready_exe_next;
                result_exe <= result_exe_next;
                csr_result_exe <= csr_result;

                ctrl_ifc.branch_pc <= pc_dec;
                ctrl_ifc.speculation_meta <= speculation_meta_dec;
                ctrl_ifc.branch_result_ready <= ready_exe_next;
                ctrl_ifc.branch_taken <= branch_taken;
                ctrl_ifc.branch_target <= alu_result;

                fwd_ifc.exe_val_valid <= exe_val_valid_next;
                fwd_ifc.rd_exe <= rd_exe_next[4:0];
                fwd_ifc.exe_val <= result_exe_next;
        end
end

endmodule
