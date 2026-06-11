`timescale 1ps / 1ps
module csru
import rv32::*;
#(
)(
        input [31:0] csr_old,
        input [31:0] rs1_value,
        input [31:0] imm,

        input csr_funct2_e op,
        input csr_src_e src,

        output logic [31:0] csr_new
);

logic [31:0] mask;

always_comb
begin
        mask = rs1_value;
        csr_new = csr_old;

        if (src == UIMM)
                mask = imm;

        case (op)
        CSRRW: csr_new = mask;
        CSRRS: csr_new = csr_old | mask;
        CSRRC: csr_new = csr_old & ~mask;
        default :;
        endcase
end

endmodule // csru
