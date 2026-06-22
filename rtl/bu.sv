`timescale 1ps / 1ps
module bu
import rv32::*;
#(
)(
        input branch_funct3_e op,

        input [31:0] rs1_val,
        input [31:0] rs2_val,

        output logic result
);

always_comb
begin
        result = 0;

        unique case(op)
        BEQ: result = rs1_val == rs2_val;
        BNE: result = rs1_val != rs2_val;
        BLT: result = $signed(rs1_val) < $signed(rs2_val);
        BGE: result = $signed(rs1_val) >= $signed(rs2_val);
        BLTU: result = rs1_val < rs2_val;
        BGEU: result = rs1_val >= rs2_val;
        endcase
end

endmodule // bu
