`timescale 1ps / 1ps
module irf
#(
)(
        input clk,
        input rst,

        input [4:0] rs1,
        input [4:0] rs2,

        output logic [31:0] rs1_val,
        output logic [31:0] rs2_val,

        input we,
        input [4:0] rd,
        input logic [31:0] rd_val
);

logic [31:0] x [0:31] /*verilator public_flat_rw*/;

always_comb
begin
        rs1_val = x[rs1];
        rs2_val = x[rs2];

        if (rs1 == rd) begin
                rs1_val = rd_val;
        end

        if (rs2 == rd) begin
                rs2_val = rd_val;
        end
end

always @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < 32; i++) begin
                        x[i] <= 0;
                end
        end else if (we) begin
                x[rd] <= rd_val;
        end
end
endmodule
