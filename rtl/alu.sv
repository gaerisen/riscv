`timescale 1ps / 1ps

module alu
import rv32::*;
#(
)(
        input alu_funct3_e op,
        input alu_funct7_e alt,
        input alu_src1_e src1,
        input alu_src2_e src2,

        input [31:0] rs1_value,
        input [31:0] rs2_value,
        input [31:0] pc_dec,
        input [31:0] imm,

        output logic [31:0] result
);

logic [31:0] in1;
logic [31:0] in2;

always_comb
begin
        in1 = rs1_value;
        in2 = rs2_value;
        result = 0;

        unique case(src1)
        ZERO: in1 = 0;
        RS1: in1 = rs1_value;
        PC: in1 = pc_dec;
        endcase

        unique case(src2)
        RS2: in2 = rs2_value;
        IMM: in2 = imm;
        endcase

        unique case(op)
        ADDSUB: begin
                unique case(alt)
                        ALT: result = in1 - in2;
                        NORM: result = in1 + in2;
                endcase
        end
        SLL: result = in1 << in2[4:0];
        SLT: result = {31'b0, $signed(in1) < $signed(in2)};
        SLTU: result = {31'b0, in1 < in2};
        XOR: result = in1 ^ in2;
        SR: begin
                unique case(alt)
                        ALT: result = $unsigned($signed(in1) >>> in2[4:0]);
                        NORM: result = in1 >> in2[4:0];
                endcase
        end
        OR: result = in1 | in2;
        AND: result = in1 & in2;
        endcase

end

endmodule
