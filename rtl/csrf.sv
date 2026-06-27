`timescale 1ps / 1ps
module csrf
#(
)(
        input clk,
        input rst,

        // Read/write port
        dispatch_ifc.csrf dispatch_ifc,

        commit_ifc.csrf commit_ifc,

        // System redirect signalling for fetch
        global_ctrl_ifc.csrf ctrl_ifc
);

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

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                dispatch_ifc.csr_val = 0;
        end
        else begin
                case (dispatch_ifc.csrs)
                12'hf11: dispatch_ifc.csr_val = mvendorid;
                12'hf12: dispatch_ifc.csr_val = marchid;
                12'hf13: dispatch_ifc.csr_val = mimpid;
                12'hf14: dispatch_ifc.csr_val = mhartid;
                12'h300: dispatch_ifc.csr_val = mstatus;
                12'h310: dispatch_ifc.csr_val = mstatush;
                12'h301: dispatch_ifc.csr_val = misa;
                12'h304: dispatch_ifc.csr_val = mie;
                12'h305: dispatch_ifc.csr_val = mtvec;
                12'h340: dispatch_ifc.csr_val = mscratch;
                12'h341: dispatch_ifc.csr_val = mepc;
                12'h342: dispatch_ifc.csr_val = mcause;
                12'h343: dispatch_ifc.csr_val = mtval;
                12'h344: dispatch_ifc.csr_val = mip;
                default: dispatch_ifc.csr_val = 0;
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

        case (commit_ifc.csr_dest)
        12'h300: mstatus_next = commit_ifc.csr_val;
        12'h310: mstatush_next = commit_ifc.csr_val;
        12'h301: misa_next = commit_ifc.csr_val;
        12'h304: mie_next = commit_ifc.csr_val;
        12'h305: mtvec_next = commit_ifc.csr_val;
        12'h340: mscratch_next = commit_ifc.csr_val;
        12'h341: mepc_next = commit_ifc.csr_val;
        12'h342: mcause_next = commit_ifc.csr_val;
        12'h343: mtval_next = commit_ifc.csr_val;
        12'h344: mip_next = commit_ifc.csr_val;
        default:;
        endcase

        if (commit_ifc.exception) begin
                mcause_next = {28'b0, commit_ifc.trap_cause};
        end
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
        ctrl_ifc.sys_redirect = 0;
        ctrl_ifc.sys_vec = 0;

        if (commit_ifc.exception) begin
                ctrl_ifc.sys_redirect = 1;
                ctrl_ifc.sys_vec = mtvec;
        end
        if (commit_ifc.trapret) begin
                ctrl_ifc.sys_redirect = 1;
                ctrl_ifc.sys_vec = mepc;
        end

        if (rst) begin
                ctrl_ifc.sys_redirect = 0;
                ctrl_ifc.sys_vec = 0;
        end
end

endmodule // csrf
