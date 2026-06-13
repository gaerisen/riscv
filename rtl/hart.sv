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

assign irf_we = commit & !(branch_commit | store_commit);

global_ctrl_ifc ctrl_ifc();

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

        if (ctrl_ifc.stall) begin
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

execute execute (
        .*
);

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
        .updated_dest(rd_exe),
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
