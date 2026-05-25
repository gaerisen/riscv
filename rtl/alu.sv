module alu
import rv32::*;
#(
)(
        input clk,
        input rst,
        input stall,
        input flush,

        input ctrl_t ctrl_i,

        input [31:0] rs1_value,
        input [31:0] rs2_value,
        input [31:0] imm,
        input [31:0] pc,

        output logic [31:0] result_o,
        output logic branch_o
);

logic [31:0] in1;
logic [31:0] in2;

logic [31:0] result_next;
logic branch_next;

initial
begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu);
end

always_comb
begin
        unique case(ctrl_i.alu_src1)
        RS1: in1 = rs1_value;
        PC: in1 = pc;
        ZERO: in1 = 0;
        default: in1 = 0;
        endcase

        unique case(ctrl_i.alu_src2)
        RS2: in2 = rs2_value;
        IMM: in2 = pc;
        default: in2 = 0;
        endcase

        unique case(ctrl_i.alu_op)
        ADDSUB: begin
                unique case(ctrl_i.alu_alt)
                        ALT: result_next = in1 - in2;
                        NORM: result_next = in1 + in2;
                        default: result_next = 0; // TODO: figure out what this
                                                        // should actually do
                endcase
        end
        SLL: result_next = in1 << in2;
        SLT: result_next = {31'b0, $signed(in1) < $signed(in2)};
        SLTU: result_next = {31'b0, in1 < in2};
        XOR: result_next = in1 ^ in2;
        SR: begin
                unique case(ctrl_i.alu_alt)
                        ALT: result_next = in1 >>> in2;
                        NORM: result_next = in1 >> in2;
                        default: result_next = 0; // TODO: figure out what this
                                                        // should actually do
                endcase
        end
        OR: result_next = in1 | in2;
        AND: result_next = in1 & in2;
        default: result_next = 0;
        endcase

        unique case(ctrl_i.branch_op)
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
        if (flush | rst) begin
                result_o <= 0;
                branch_o <= 0;
        end else if (!stall) begin
                result_o <= result_next;
                branch_o <= branch_next;
        end
end

endmodule;
