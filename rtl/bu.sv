`timescale 1ps / 1ps
module bu
import rv32::*;
#(
)(
        input branch_funct3_e op,

        input [31:0] rs1_value,
        input [31:0] rs2_value,

        output logic result
);

always_comb
begin
        result = 0;

        unique case(op)
        BEQ: result = rs1_value == rs2_value;
        BNE: result = rs1_value != rs2_value;
        BLT: result = $signed(rs1_value) < $signed(rs2_value);
        BGE: result = $signed(rs1_value) >= $signed(rs2_value);
        BLTU: result = rs1_value < rs2_value;
        BGEU: result = rs1_value >= rs2_value;
        endcase
end

endmodule // bu
