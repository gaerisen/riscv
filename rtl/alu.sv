`timescale 1ps / 1ps

module alu
import rv32::*;
#(
)(
        input alu_funct3_e op,
        input alu_funct7_e alt,
        input alu_src_e src,

        input [31:0] rs1_val,
        input [31:0] rs2_val,
        input [31:0] pc,
        input [31:0] imm,

        output logic [31:0] result
);

logic [31:0] in1;
logic [31:0] in2;

always_comb
begin
        result = 0;

        unique case(src)
        REG_REG: begin
                in1 = rs1_val;
                in2 = rs2_val;
        end
        REG_IMM: begin
                in1 = rs1_val;
                in2 = imm;
        end
        ZERO_IMM: begin
                in1 = 0;
                in2 = imm;
        end
        PC_IMM: begin
                in1 = pc;
                in2 = imm;
        end
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
