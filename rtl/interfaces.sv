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

logic rs_stall;
logic rob_stall;
logic stall;
logic flush;

assign stall = rs_stall | rob_stall;

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
        output rob_stall
);

modport decode (
        input flush, stall
);

modport execute (
        input flush,
        output branch_pc, speculation_meta,
        output branch_result_ready, branch_taken, branch_target
);

modport rs (
        output rs_stall
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

logic [11:0] csrs;

logic [31:0] csr_val;

assign csrs = instr.i.imm11_0;

modport fetch (
        output pc, instr, valid, speculation_meta
);

modport csrf_read (
        input csrs,
        output csr_val
);

modport decode (
        input pc, instr, valid, speculation_meta,
        csrs, csr_val
);

endinterface


/*=================*/
/*    Issue Ifc    */
/*=================*/
interface issue_ifc 
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        parameter int ROB_LEN = 64,
        localparam int ROB_BITS = $clog2(ROB_LEN)
)(
);

logic issue;
ctrl_t ctrl_word;
logic [31:0] pc;
logic [31:0] imm;
logic [PRF_BITS-1:0] prs1;
logic [PRF_BITS-1:0] prs2;
logic [PRF_BITS-1:0] prd_old;
logic [PRF_BITS-1:0] prd_new;
speculation_meta_t speculation_meta;
logic [5:0] tag;

modport decode (
        output issue, ctrl_word, pc, imm, speculation_meta,
        prs1, prs2, prd_old, prd_new
);

modport rob (
        input issue, ctrl_word, pc,
        output tag
);

modport rs (
        input issue, ctrl_word, pc, imm, speculation_meta,
        prs1, prs2, prd_old, prd_new, tag
);

endinterface

/*====================*/
/*    Dispatch Ifc    */
/*====================*/
interface dispatch_ifc
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        parameter int ROB_LEN = 64,
        localparam int ROB_BITS = $clog2(ROB_LEN)
)(
);

logic dispatch;
ctrl_t ctrl_word;
speculation_meta_t speculation_meta;
logic [PRF_BITS-1:0] prs1;
logic [PRF_BITS-1:0] prs2;
logic [PRF_BITS-1:0] prd_old;
logic [PRF_BITS-1:0] prd_new;
logic [31:0] rs1_val;
logic [31:0] rs2_val;
logic [31:0] pc;
logic [31:0] imm;
logic [5:0] tag;

modport rs (
        output prs1, prs2, // Asynchronous
        output dispatch, ctrl_word, prd_old, prd_new, pc, imm, tag, // Synchronous
        speculation_meta
);

modport prf (
        input prs1, prs2,
        output rs1_val, rs2_val
);

modport execute (
        input dispatch, ctrl_word, rs1_val, rs2_val, pc, imm, prd_old, prd_new,
        tag, speculation_meta
);

endinterface: dispatch_ifc


/*=======================*/
/*    Common Data Ifc    */
/*=======================*/
interface cdb_ifc
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        parameter int ROB_LEN = 64,
        localparam int ROB_BITS = $clog2(ROB_LEN)
)(
);

logic update;
logic [ROB_BITS-1:0] tag;
logic [31:0] value;
logic [PRF_BITS-1:0] dest;
logic [PRF_BITS-1:0] dest_old;

modport execute (
        output update, tag, value, dest, dest_old
);

modport rs (
        input update, dest
);

modport prf (
        input dest, value
);

modport rob (
        input update, tag, value, dest, dest_old
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
logic [5:0] dest;
logic [5:0] dest_old;
logic [31:0] csr_value;
logic [11:0] csr_dest;

logic irf_select;

assign irf_select = commit & !(store | branch | exception | trapret);

modport rob (
        output commit, store, branch, exception, trapret,
        trap_cause, value, dest, dest_old, csr_value, csr_dest
);

modport csrf (
        input commit, exception, trapret, trap_cause,
        csr_dest, csr_value
);

modport irf (
        input irf_select, dest, value
);

modport decode (
        input commit, dest_old
);

endinterface
