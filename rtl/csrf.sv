`timescale 1ps / 1ps
module csrf
import rv32::*;
#(
)(
        input clk,
        input rst,

        // Read/write port
        input csr_rd,
        input [11:0] csrs,

        input [11:0] csrd,
        input [31:0] csr_wb,

        output logic [31:0] csrs_value,

        // System word from decoder
        input system_t sys_word,

        // System redirect port
        output logic sys_redirect,
        output logic [31:0] sys_vec
);

logic sys_redirect_next;
logic [31:0] sys_vec_next;

logic [31:0] mvendorid;
logic [31:0] marchid;
logic [31:0] mimpid;
logic [31:0] mhartid;

logic [31:0] mstatus, mstatus_next;
logic [31:0] mstatush, mstatush_next;
logic [31:0] misa, misa_next;
logic [31:0] mie, mie_next;
logic [31:0] mtvec, mtvec_next;

logic [31:0] mscratch, mscratch_next;
logic [31:0] mepc, mepc_next;
logic [31:0] mcause, mcause_next;
logic [31:0] mtval, mtval_next;
logic [31:0] mip, mip_next;

//==================================
//      CSR READ
//==================================

always_comb
begin
        csrs_value = 0;

        if (csr_rd) begin
                case (csrs)
                12'hf11: csrs_value = mvendorid;
                12'hf12: csrs_value = marchid;
                12'hf13: csrs_value = mimpid;
                12'hf14: csrs_value = mhartid;
                12'h300: csrs_value = mstatus;
                12'h310: csrs_value = mstatush;
                12'h301: csrs_value = misa;
                12'h304: csrs_value = mie;
                12'h305: csrs_value = mtvec;
                12'h340: csrs_value = mscratch;
                12'h341: csrs_value = mepc;
                12'h342: csrs_value = mcause;
                12'h343: csrs_value = mtval;
                12'h344: csrs_value = mip;
                default:;
                endcase
        end
end

//==================================
//      CSR WRITE
//==================================

always_comb
begin
        mstatus_next = mstatus;
        mstatush_next = mstatush;
        misa_next = misa;
        mie_next = mie;
        mtvec_next = mtvec;
        mscratch_next = mscratch;
        mepc_next = mepc;
        mcause_next = mcause;
        mtval_next = mtval;
        mip_next = mip;

        case (csrd)
        12'h300: mstatus_next = csr_wb;
        12'h310: mstatush_next = csr_wb;
        12'h301: misa_next = csr_wb;
        12'h304: mie_next = csr_wb;
        12'h305: mtvec_next = csr_wb;
        12'h340: mscratch_next = csr_wb;
        12'h341: mepc_next = csr_wb;
        12'h342: mcause_next = csr_wb;
        12'h343: mtval_next = csr_wb;
        12'h344: mip_next = csr_wb;
        default:;
        endcase

        if (sys_word.ebreak)
                mcause_next = 3;
        else if (sys_word.illegal)
                mcause_next = 2;
        else if (sys_word.ecall)
                mcause_next = 11;
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                mvendorid <= 0;
                marchid <= 0;
                mimpid <= 32'hdeadbeef;
                mhartid <= 0;
                mstatus <= 0;
                mstatush <= 0;
                misa <= 32'h80001105; // RV32IMAC
                mie <= 0;
                mtvec <= 0;
                mscratch <= 0;
                mepc <= 0;
                mcause <= 0;
                mtval <= 0;
                mip <= 0;
        end
        else begin
                mstatus <= mstatus_next;
                mstatush <= mstatush_next;
                misa <= misa_next;
                mie <= mie_next;
                mtvec <= mtvec_next;
                mscratch <= mscratch_next;
                mepc <= mepc_next;
                mcause <= mcause_next;
                mtval <= mtval_next;
                mip <= mip_next;
        end
end

//==================================
//      SYSTEM CONTROL
//==================================

always_comb
begin
        sys_redirect_next = 0;
        sys_vec_next = 0;

        if (sys_word.illegal | sys_word.ecall | sys_word.ebreak) begin
                sys_redirect_next = 1;
                sys_vec_next = mtvec;
        end
        if (sys_word.mret) begin
                sys_redirect_next = 1;
                sys_vec_next = mepc;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                sys_redirect <= 0;
                sys_vec <= 0;
        end
        else begin
                sys_redirect <= sys_redirect_next;
                sys_vec <= sys_vec_next;
        end
end

endmodule // csrf
