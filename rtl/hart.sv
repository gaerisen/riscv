`timescale 1ps / 1ps
module hart
import rv32::*;
#(
        parameter int ROB_LEN = 32,
        localparam int ROB_BITS = $clog2(ROB_LEN)
)
(
        input clk,
        input rst,

        output logic [31:0] i_addr,

        input i_data_ready,
        input [31:0] i_data,

        output logic [31:0] d_addr,
        output logic d_valid,
        output logic d_we,
        output store_funct3_e d_st_op,
        output logic [31:0] d_data_o,

        input logic d_ready,
        input logic [31:0] d_data_i
);

`include "hart-sigs.svh"

speculation_meta_t speculation_meta_fet;
speculation_meta_t speculation_meta_dec;
speculation_meta_t speculation_meta_exe;

assign irf_we = commit & !(branch_commit | store_commit);

// Integer register file
irf irf(
        .*,

        .we(irf_we),
        .rd(rd_commit[4:0]),
        .rd_val(wb_commit)
);

// Control/status register file
csrf csrf(
        .*,

        .csrs_value(csr_read),

        .csrd(csrd_commit),
        .csr_result(csrwb_commit)
);

//==============================================================================
//                              PIPELINE
//==============================================================================
//======================================
//      (1) Fetch
//======================================

fetch fetch (
        .*,

        .pc_o(pc_fet),
        .instr_o(instr),
        .valid_o(valid),
        .flush_o(flush),
        .speculation_meta(speculation_meta_fet)
);

//======================================
//      (2a) Reg read 
//======================================

assign rs1 = instr.r.rs1;
assign rs2 = instr.r.rs2;
assign csrs = instr.i.imm11_0;

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                rs1_dec <= 0;
                rs2_dec <= 0;
                csrs_dec <= 0;
                csr_val_dec <= 0;
        end
        else begin
                rs1_dec <= rs1;
                rs2_dec <= rs2;
                rs1_val_dec <= rs1_val; // direct from irf module
                rs2_val_dec <= rs2_val; // direct from irf module
                csrs_dec <= csrs;
                csr_val_dec <= csr_read;
        end
end
        

//======================================
//      (2b) Decode
//======================================

decoder decoder (
        .*,

        .instr_i(instr),

        .imm_o(imm),
        .rd_o(rd_dec),

        .ctrl_o(ctrl_dec)
);

always_comb
begin
        issue_next = valid;

        if (rob_stall) begin
                issue_next = 0;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_dec <= 0;
                speculation_meta_dec <= 0;
                issue <= 0;
        end
        else begin
                pc_dec <= pc_fet;
                speculation_meta_dec <= speculation_meta_fet;
                issue <= issue_next;
        end
end


//======================================
//      (3) Execute        
//======================================

// Operand forwarding
always_comb
begin
        rs1_value = rs1_val_dec;
        rs2_value = rs2_val_dec;
        csr_value = csr_val_dec;

        if (rs1_dec == 0)
                rs1_value = 0;
        else if (!flush & ready_exe & ctrl_exe.irf_we & (rs1_dec == rd_exe))
                rs1_value = result_exe;
        else if (commit & !(branch_commit | store_commit) & (rs1_dec == rd_commit[4:0]))
                rs1_value = wb_commit;

        if (rs2_dec == 0)
                rs2_value = 0;
        else if (!flush & ready_exe & ctrl_exe.irf_we & (rs2_dec == rd_exe))
                rs2_value = result_exe;
        else if (commit & !(branch_commit | store_commit) & (rs2_dec == rd_commit[4:0]))
                rs2_value = wb_commit;
end


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

        .csr_old(csr_value),

        .csr_new(csr_result)
);

// Result selection
always_comb
begin
        ready_exe_next = 0;
        result_exe_next = 0;

        if (!flush) begin
                ready_exe_next = issue;
        end

        unique case (ctrl_dec.wb_src)
        WB_ALU: begin // Decoder lets default value thru for stores
                if (ctrl_dec.store)
                        result_exe_next = rs2_value;
                else
                        result_exe_next = alu_result;
        end
        WB_MEM: result_exe_next = 0; // TODO: Come on, bro
        WB_PC4: result_exe_next = pc_dec + 4;
        WB_CSR: result_exe_next = csr_value;
        endcase

        if (ctrl_dec.jump | ctrl_dec.branch | ctrl_dec.store) begin
                target_addr_exe_next = alu_result;
        end
        else begin
                target_addr_exe_next = 0;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_exe <= 0;
                ctrl_exe <= 0;
                rd_exe <= 0;
                ready_exe <= 0;
                result_exe <= 0;
                branch_taken_exe <= 0;
                target_addr_exe <= 0;
                csr_result_exe <= 0;
                speculation_meta_exe <= 0;
        end
        else begin
                pc_exe <= pc_dec;
                ctrl_exe <= ctrl_dec;
                rd_exe <= rd_dec;
                ready_exe <= ready_exe_next;
                result_exe <= result_exe_next;
                branch_taken_exe <= branch_taken;
                target_addr_exe <= target_addr_exe_next;
                csr_result_exe <= csr_result;
                speculation_meta_exe <= speculation_meta_dec;
        end
end


//======================================
//      (4) Memory Access
//======================================



//======================================
//      (5) Writeback/Commit
//======================================
rob rob (
        .*,

        .issued_dest({27'b0, rd_dec}),
        .issued_csr_dest(csrs_dec),
        .issued_ctrl(ctrl_dec),
        .issued_pc(pc_dec),

        .issued_ptr(rob_ptr_exe),
        
        .update_entry(ready_exe),
        .result(result_exe),
        .csr_result(csr_result_exe),
        .updated_dest(target_addr_exe),
        .entry_idx(rob_ptr_exe),

        .store(store_commit),
        .branch(branch_commit),
        .rd(rd_commit),
        .wb(wb_commit),
        .csrd(csrd_commit),
        .csrwb(csrwb_commit)
);

defparam rob.ROB_LEN = ROB_LEN;

always_comb
begin
        d_addr = 0;
        d_valid = 0;
        d_data_o = 0;
        d_we = 0;
        d_st_op = SB;

        if (store_commit) begin
                d_valid = 1;
                d_we = 1;
                d_addr = rd_commit;
                d_data_o = wb_commit;
        end
end
endmodule // hart
