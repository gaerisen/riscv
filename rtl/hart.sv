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

assign irf_we = commit & !(branch_commit | store_commit);

global_ctrl_ifc ctrl_ifc();
fet_to_dec_ifc fet_dec_ifc();
fwding_ifc fwd_ifc();
issue_ifc issue_ifc();

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
        .*
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
                rs1_dec <= fet_dec_ifc.rs1;
                rs2_dec <= fet_dec_ifc.rs2;
                rs1_val_dec <= fet_dec_ifc.rs1_val; // direct from irf module
                rs2_val_dec <= fet_dec_ifc.rs2_val; // direct from irf module
                csrs_dec <= fet_dec_ifc.csrs;
                csr_val_dec <= fet_dec_ifc.csr_val;
        end
end

// [Temporary] give fwding network read values
always_comb
begin
        fwd_ifc.rs1 = rs1_dec;
        fwd_ifc.rs2 = rs2_dec;
        fwd_ifc.rs1_val = rs1_val_dec;
        fwd_ifc.rs2_val = rs2_val_dec;
end
        

//======================================
//      (2b) Decode
//======================================

decode decode (
        .*
);


//======================================
//      (3) Execute        
//======================================

execute execute (
        .*
);

logic [11:0] csrd_exe;
always_ff @(posedge clk or posedge rst)
begin
        if (rst)
                csrd_exe <= 0;
        else
                csrd_exe <= csrs_dec;
end

//======================================
//      (4) Memory Access
//======================================



//======================================
//      (5) Writeback/Commit
//======================================
rob rob (
        .*,

        .issued_ptr(rob_ptr_exe),
        
        .update_entry(ready_exe),
        .result(result_exe),
        .csr_result(csr_result_exe),
        .updated_dest(rd_exe),
        .updated_csr_dest(csrd_exe),
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
