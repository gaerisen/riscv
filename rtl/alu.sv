`timescale 1ps / 1ps

module alu
import rv32::*;
#(
)(
        input alu_funct3_e op,
        input alu_funct7_e alt,

        input [31:0] in1,
        input [31:0] in2,

        output logic [31:0] result
);

always_comb
begin
        result = 0;


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
