`timescale 1ps / 1ps
module irf
#(
)(
        input clk,
        input rst,

        fet_to_dec_ifc.irf_read fet_dec_ifc,

        commit_ifc.irf commit_ifc
);

logic [31:0] x [0:31] /*verilator public_flat_rw*/;

always_comb
begin
        fet_dec_ifc.rs1_val = x[fet_dec_ifc.rs1];
        fet_dec_ifc.rs2_val = x[fet_dec_ifc.rs2];

        if (commit_ifc.irf_select) begin
                if (fet_dec_ifc.rs1 == commit_ifc.dest[4:0]) begin
                        fet_dec_ifc.rs1_val = commit_ifc.value;
                end

                if (fet_dec_ifc.rs2 == commit_ifc.dest[4:0]) begin
                        fet_dec_ifc.rs2_val = commit_ifc.value;
                end
        end
end

always @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < 32; i++) begin
                        x[i] <= 0;
                end
        end else if (commit_ifc.irf_select) begin
                x[commit_ifc.dest] <= commit_ifc.value;
        end
end
endmodule
