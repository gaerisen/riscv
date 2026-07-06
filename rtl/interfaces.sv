`timescale 1ps / 1ps


/*==========================*/
/*    Global Control Ifc    */
/*==========================*/
interface global_ctrl_ifc
#(
        parameter int ROB_LEN = 64,
        localparam int ROB_BITS = $clog2(ROB_LEN),
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        localparam int FREE_SIZE = PRF_SIZE - 32,
        localparam int FREE_BITS = $clog2(FREE_SIZE)
)(
        input clk,
        input rst,
        input external_stall
);

logic sys_redirect;
logic [31:0] sys_vec;

logic rs_stall;
logic rob_stall;
logic [ROB_BITS-1:0] tag;
logic stall;
logic internal_stall;
logic flush;

logic [31:0][PRF_BITS-1:0] rat;
logic [FREE_SIZE-1:0][PRF_BITS-1:0] free_list;
logic [FREE_BITS-1:0] free_head;
logic [FREE_BITS-1:0] free_tail;

assign internal_stall = rs_stall | rob_stall;
assign stall = internal_stall | external_stall;

logic stall_exit;
logic stall_dly;

always @(posedge clk or posedge rst)
begin
        if (rst) begin
                stall_dly <= 0;
        end
        else begin
                stall_dly <= internal_stall;
        end
end

assign stall_exit = stall_dly & ~internal_stall;

modport fetch (
        input internal_stall, external_stall, stall, sys_redirect, sys_vec,
        output flush
);

modport csrf (
        output sys_redirect, sys_vec
);

modport rob (
        input flush, tag,
        output rob_stall, rat, free_list, free_head, free_tail
);

modport decode (
        input flush, internal_stall, stall_exit, rat, free_list, free_head, free_tail
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


/*====================*/
/*    Dispatch Ifc    */
/*====================*/
interface dispatch_ifc 
import rv32::*;
#(
        parameter int PRF_SIZE,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        parameter int ROB_LEN,
        localparam int ROB_BITS = $clog2(ROB_LEN),
        localparam int FREE_SIZE = PRF_SIZE,
        localparam int FREE_BITS = $clog2(FREE_SIZE)
)(
);

logic dispatch /* verilator public */;
ctrl_t ctrl_word;
logic [31:0] spec_mask;
logic [31:0] pc /* verilator public */;
logic [31:0] imm;
logic [PRF_BITS-1:0] prs1;
logic [PRF_BITS-1:0] prs2;
logic [11:0] csrs;
logic [PRF_BITS-1:0] prd_old;
logic [PRF_BITS-1:0] prd_new;
speculation_meta_t speculation_meta;
logic [ROB_BITS-1:0] tag;

logic [31:0][PRF_BITS-1:0] rat;
logic [FREE_BITS-1:0] free_head;

logic [PRF_SIZE-1:0] preg_ready;

modport decode (
        output dispatch, ctrl_word, pc, imm, speculation_meta, spec_mask,
        prs1, prs2, csrs, prd_old, prd_new, rat, free_head
);

modport rob (
        input dispatch, ctrl_word, pc, rat, free_head, speculation_meta, preg_ready, spec_mask,
        output tag
);

modport prf (
        input dispatch, prd_new,
        output preg_ready
);

modport rs (
        input dispatch, ctrl_word, pc, imm, preg_ready, spec_mask,
        prs1, prs2, csrs, prd_old, prd_new, tag
);

endinterface



/*====================*/
/*    Dispatch Ifc    */
/*====================*/
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
logic [PRF_BITS-1:0] prs1;
logic [PRF_BITS-1:0] prs2;
logic [PRF_BITS-1:0] prd_old;
logic [PRF_BITS-1:0] prd_new;
logic [11:0] csrs;
logic [11:0] csrd;
logic [31:0] rs1_val;
logic [31:0] rs2_val;
logic [31:0] csr_val;
logic [31:0] pc;
logic [31:0] imm;
logic [5:0] tag;

modport rs (
        output prs1, prs2, csrs, // Asynchronous
        output issue, ctrl_word, prd_old, prd_new, csrd, pc, imm, tag // Synchronous
);

modport prf (
        input prs1, prs2,
        output rs1_val, rs2_val
);

modport csrf (
        input csrs,
        output csr_val
);

modport execute (
        input issue, ctrl_word, rs1_val, rs2_val, pc, imm, prd_old, prd_new,
        tag, csr_val, csrd
);

modport rob (
        input issue, tag
);

endinterface: issue_ifc


/*=======================*/
/*    Common Data Ifc    */
/*=======================*/
interface cdb_ifc
import rv32::*;
#(
        parameter int PRF_SIZE,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        parameter int ROB_LEN,
        localparam int ROB_BITS = $clog2(ROB_LEN),
        localparam int FREE_SIZE = PRF_SIZE,
        localparam int FREE_BITS = $clog2(FREE_SIZE)
)(
);

logic update;
logic [ROB_BITS-1:0] tag;
logic [31:0] spec_mask;
logic valid;

logic [31:0] value;
logic branch_taken;
logic [31:0] target_addr;
logic [31:0] pc;

logic [PRF_BITS-1:0] dest;
logic [PRF_BITS-1:0] dest_old;

logic [11:0] csrd;
logic [31:0] csr_result;

speculation_meta_t speculation_meta;
logic branch_mis_t;
logic branch_mis_nt;
logic jump_mis;
logic rollback;

logic [31:0][PRF_BITS-1:0] rat;
logic [FREE_BITS-1:0] free_head;

logic [PRF_SIZE-1:0] preg_ready;

assign branch_mis_t = update & speculation_meta.branch &
        (speculation_meta.branch_taken & ~branch_taken);

assign branch_mis_nt = update & speculation_meta.branch &
        (~speculation_meta.branch_taken & branch_taken);

assign jump_mis = update & speculation_meta.jump & 
        (speculation_meta.target != target_addr);

assign rollback = branch_mis_t | branch_mis_nt | jump_mis;

modport decode (
        input rollback, rat, free_head
);

modport execute (
        output update, tag, value, dest, dest_old, branch_taken, target_addr, pc,
        csrd, csr_result
);

modport rs (
        input update, valid, dest, spec_mask, rollback
);

modport prf (
        input update, dest, value, rollback, preg_ready, valid
);

modport rob (
        input update, tag, value, dest, dest_old, rollback, csrd, csr_result,
        output speculation_meta, rat, free_head, preg_ready, valid, spec_mask
);

modport fetch (
        input update, valid, speculation_meta, branch_taken,
        branch_mis_t, branch_mis_nt, jump_mis, target_addr, pc
);

endinterface


/*==================*/
/*    Commit Ifc    */
/*==================*/
interface commit_ifc 
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE)
)(
);

logic commit;
logic ready;
logic store;
logic branch;
logic exception;
logic trapret;
trap_cause_e trap_cause;
logic [31:0] value;
logic [PRF_BITS-1:0] dest;
logic [PRF_BITS-1:0] dest_old;
logic [31:0] csr_val;
logic [11:0] csr_dest;

logic irf_select;

assign irf_select = commit & !(store | branch | exception | trapret);

modport rob (
        output commit, ready, store, branch, exception, trapret,
        trap_cause, value, dest, dest_old, csr_val, csr_dest
);

modport csrf (
        input commit, exception, trapret, trap_cause,
        csr_dest, csr_val
);

modport irf (
        input irf_select, dest, value
);

modport decode (
        input commit, dest_old
);

endinterface
