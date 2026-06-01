`timescale 1ps / 1ps
module csru
import rv32::*;
#(
)(
        input clk,
        input rst,

        input [31:0] csr_old,
        input [31:0] rs1_value,
        input [31:0] imm,

        input ctrl_t ctrl_i,

        output logic [31:0] csr_new
);

logic [31:0] csr_new_next;
logic [31:0] mask;

always_comb
begin
        mask = rs1_value;

        if (ctrl_i.csr_src == UIMM)
                mask = imm;

        unique case (ctrl_i.csr_op)
        CSRRW: csr_new_next = mask;
        CSRRS: csr_new_next = csr_old | mask;
        CSRRC: csr_new_next = csr_old & ~mask;
        NONE: csr_new_next = csr_old;
        endcase
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                csr_new <= 0;
        end
        else begin
                csr_new <= csr_new_next;
        end
end

endmodule // csru
