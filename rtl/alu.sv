`timescale 1ps / 1ps

module alu
import rv32::*;
#(
)(
        input clk,
        input rst,

        input sel,
        input alu_funct3_e op,
        input alu_funct7_e alt,

        input [31:0] in1,
        input [31:0] in2,

        output logic ready,
        output logic [31:0] result
);

logic [31:0] result_next;

always_comb
begin
        result_next = 0;

/*        unique case(ctrl_i.alu_src1)
        ZERO: in1 = 0;
        RS1: in1 = rs1_value;
        PC: in1 = pc_dec;
        endcase

        unique case(ctrl_i.alu_src2)
        RS2: in2 = rs2_value;
        IMM: in2 = imm;
        endcase */

        unique case(op)
        ADDSUB: begin
                unique case(alt)
                        ALT: result_next = in1 - in2;
                        NORM: result_next = in1 + in2;
                endcase
        end
        SLL: result_next = in1 << in2[4:0];
        SLT: result_next = {31'b0, $signed(in1) < $signed(in2)};
        SLTU: result_next = {31'b0, in1 < in2};
        XOR: result_next = in1 ^ in2;
        SR: begin
                unique case(alt)
                        ALT: result_next = $unsigned($signed(in1) >>> in2[4:0]);
                        NORM: result_next = in1 >> in2[4:0];
                endcase
        end
        OR: result_next = in1 | in2;
        AND: result_next = in1 & in2;
        endcase

end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                result <= 0;
                ready <= 0;
        end else begin
                result <= result_next;
                ready <= sel;
        end
end

endmodule
