`timescale 1ps / 1ps
module irf
#(
)(
        input clk,
        input rst,

        fet_to_dec_ifc.irf_read fet_dec_ifc,

        input we,
        input [4:0] rd,
        input logic [31:0] rd_val
);

logic [31:0] x [0:31] /*verilator public_flat_rw*/;

always_comb
begin
        fet_dec_ifc.rs1_val = x[fet_dec_ifc.rs1];
        fet_dec_ifc.rs2_val = x[fet_dec_ifc.rs2];

        if (fet_dec_ifc.rs1 == rd) begin
                fet_dec_ifc.rs1_val = rd_val;
        end

        if (fet_dec_ifc.rs2 == rd) begin
                fet_dec_ifc.rs2_val = rd_val;
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
