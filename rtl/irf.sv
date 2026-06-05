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

logic [31:0] irf [0:31];

assign rs1_val = irf[rs1];
assign rs2_val = irf[rs2];

always @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < 32; i++) begin
                        irf[i] <= 0;
                end
        end else if (we) begin
                irf[rd] <= rd_val;
        end
end
endmodule
