`timescale 1ps / 1ps
module bu
import rv32::*;
#(
)(
        input clk,
        input rst,

        input sel,
        input branch_funct3_e op,

        input [31:0] in1,
        input [31:0] in2,

        output logic ready,
        output logic branch_result
);

logic branch_next;

always_comb
begin
        branch_next = 0;

        unique case(op)
        BEQ: branch_next = in1 == in2;
        BNE: branch_next = in1 != in2;
        BLT: branch_next = $signed(in1) < $signed(in2);
        BGE: branch_next = $signed(in1) >= $signed(in2);
        BLTU: branch_next = in1 < in2;
        BGEU: branch_next = in1 >= in2;
        endcase
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                ready <= 0;
                branch_result <= 0;
        end
        else begin
                ready <= sel;
                branch_result <= branch_next;
        end
end

endmodule // bu
