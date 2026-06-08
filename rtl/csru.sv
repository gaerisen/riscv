`timescale 1ps / 1ps
module csru
import rv32::*;
#(
)(
        input clk,
        input rst,

        input sel,
        input [31:0] csr_old,
        input [31:0] rs1_value,
        input [31:0] imm,

        input csr_funct2_e op,
        input csr_src_e src,

        output logic ready,
        output logic [31:0] csr_new
);

logic [31:0] csr_new_next;
logic [31:0] mask;

always_comb
begin
        mask = rs1_value;
        csr_new_next = csr_old;

        if (src == UIMM)
                mask = imm;

        case (op)
        CSRRW: csr_new_next = mask;
        CSRRS: csr_new_next = csr_old | mask;
        CSRRC: csr_new_next = csr_old & ~mask;
        default :;
        endcase
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                csr_new <= 0;
                ready <= 0;
        end
        else begin
                csr_new <= csr_new_next;
                ready <= sel;
        end
end

endmodule // csru
