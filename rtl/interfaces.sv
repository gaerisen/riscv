`timescale 1ps / 1ps


/*==========================*/
/*    Global Control Ifc    */
/*==========================*/
interface global_ctrl_ifc
import rv32::*;
#(
)(
);

logic sys_redirect;
logic [31:0] sys_vec;

logic [31:0] branch_pc;
logic branch_result_ready;
speculation_meta_t speculation_meta;
logic branch_taken;
logic [31:0] branch_target;

logic stall;
logic flush;

modport fetch (
        input stall, sys_redirect, sys_vec,
        input branch_pc, speculation_meta,
        input branch_result_ready, branch_taken, branch_target,
        output flush
);

modport csrf (
        output sys_redirect, sys_vec
);

modport rob (
        input flush,
        output stall
);

modport decode (
        input flush, stall
);

modport execute (
        input flush,
        output branch_pc, speculation_meta,
        output branch_result_ready, branch_taken, branch_target
);

endinterface


/*=========================*/
/*    Fetch->Decode Ifc    */
/*=========================*/
interface fet_to_dec_ifc 
import rv32::*;
#(
)(
);

logic [31:0] pc;
instr_t instr;
logic valid;
speculation_meta_t speculation_meta;

logic [4:0] rs1;
logic [4:0] rs2;
logic [11:0] csrs;

logic [31:0] rs1_val;
logic [31:0] rs2_val;
logic [31:0] csr_val;

assign rs1 = instr.r.rs1;
assign rs2 = instr.r.rs2;
assign csrs = instr.i.imm11_0;

modport fetch (
        output pc, instr, valid, speculation_meta
);

// Need registerfile modports for inline RF read
modport irf_read (
        input rs1, rs2,
        output rs1_val, rs2_val
);

modport csrf_read (
        input csrs,
        output csr_val
);

modport decode (
        input pc, instr, valid, speculation_meta
);

endinterface


/*======================*/
/*    Forwarding Ifc    */
/*======================*/
interface fwding_ifc
#(
)(
);

logic [4:0] rs1;
logic [4:0] rs2;

logic [31:0] rs1_val;
logic [31:0] rs2_val;

logic exe_val_valid;
logic [4:0] rd_exe;
logic [31:0] exe_val;

logic commit_val_valid;
logic [4:0] rd_commit;
logic [31:0] commit_val;

logic [31:0] in1;
logic [31:0] in2;

always_comb
begin
        if (rs1 == 0)
                in1 = 0;
        else if (exe_val_valid & (rs1 == rd_exe))
                in1 = exe_val;
        else if (commit_val_valid & (rs1 == rd_commit))
                in1 = commit_val;
        else
                in1 = rs1_val;
                
        if (rs2 == 0)
                in2 = 0;
        else if (exe_val_valid & (rs2 == rd_exe))
                in2 = exe_val;
        else if (commit_val_valid & (rs2 == rd_commit))
                in2 = commit_val;
        else
                in2 = rs2_val;
end

modport decode (
        output rs1, rs1_val,
               rs2, rs2_val
);

modport execute (
        input in1, in2,
        output exe_val_valid, rd_exe, exe_val
);

modport commit (
        output commit_val_valid, rd_commit, commit_val
);

endinterface


/*=================*/
/*    Issue Ifc    */
/*=================*/
interface issue_ifc 
import rv32::*;
#(
        parameter int ROB_LEN = 64,
        localparam int ROB_BITS = $clog2(ROB_LEN)
)(
);

logic issue;
ctrl_t ctrl_word;
logic [31:0] pc;
logic [31:0] imm;
logic [4:0] rd;
speculation_meta_t speculation_meta;
logic [ROB_BITS-1:0] tag;

modport decode (
        output issue, ctrl_word, pc, imm, rd, speculation_meta
);

modport rob (
        input issue, ctrl_word, pc,
        output tag
);

modport execute (
        input issue, ctrl_word, pc, imm, rd, speculation_meta, tag
);

endinterface


/*======================*/
/*    ROB Update Ifc    */
/*======================*/
interface cdb_ifc
#(
        parameter int ROB_LEN = 64,
        localparam int ROB_BITS = $clog2(ROB_LEN)
)(
);

logic update;
logic [ROB_BITS-1:0] tag;
logic [31:0] value;
logic [31:0] dest;
logic [31:0] csr_value;
logic [11:0] csr_dest;

modport execute (
        output update, tag, value, dest, csr_value, csr_dest
);

modport rob (
        input update, tag, value, dest, csr_value, csr_dest
);

endinterface


/*==================*/
/*    Commit Ifc    */
/*==================*/
interface commit_ifc 
import rv32::*;
#(
)(
);

logic commit;
logic store;
logic branch;
logic exception;
logic trapret;
trap_cause_e trap_cause;
logic [31:0] value;
logic [31:0] dest;
logic [31:0] csr_value;
logic [11:0] csr_dest;

logic irf_select;

assign irf_select = commit & !(store | branch | exception | trapret);

modport rob (
        output commit, store, branch, exception, trapret,
        trap_cause, value, dest, csr_value, csr_dest
);

modport csrf (
        input commit, exception, trapret, trap_cause,
        csr_dest, csr_value
);

modport irf (
        input irf_select, dest, value
);

endinterface
