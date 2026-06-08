`timescale 1ps / 1ps
module bu
import rv32::*;
#(
)(
        input clk,
        input rst,

        input sel,
        input branch_funct3_e op,

        input [31:0] rs1_value,
        input [31:0] rs2_value,

        output logic ready,
        output logic result
);

logic branch_next;

always_comb
begin
        branch_next = 0;

        unique case(op)
        BEQ: branch_next = rs1_value == rs2_value;
        BNE: branch_next = rs1_value != rs2_value;
        BLT: branch_next = $signed(rs1_value) < $signed(rs2_value);
        BGE: branch_next = $signed(rs1_value) >= $signed(rs2_value);
        BLTU: branch_next = rs1_value < rs2_value;
        BGEU: branch_next = rs1_value >= rs2_value;
        endcase
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                ready <= 0;
                result <= 0;
        end
        else begin
                ready <= sel;
                result <= branch_next;
        end
end

endmodule // bu
