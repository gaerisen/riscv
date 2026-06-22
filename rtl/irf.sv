`timescale 1ps / 1ps
module irf
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE)
)(
        input clk,
        input rst,

        fet_to_dec_ifc.irf_read fet_dec_ifc,

        commit_ifc.irf commit_ifc
);

logic [31:0] x [0:PRF_SIZE-1] /*verilator public_flat_rw*/;

always_comb
begin
        fet_dec_ifc.rs1_val = x[fet_dec_ifc.prs1];
        fet_dec_ifc.rs2_val = x[fet_dec_ifc.prs2];

        if (commit_ifc.irf_select) begin
                if (fet_dec_ifc.prs1 == commit_ifc.dest[PRF_BITS-1:0]) begin
                        fet_dec_ifc.rs1_val = commit_ifc.value;
                end

                if (fet_dec_ifc.prs2 == commit_ifc.dest[PRF_BITS-1:0]) begin
                        fet_dec_ifc.rs2_val = commit_ifc.value;
                end
        end
end

always @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < PRF_SIZE; i++) begin
                        x[i] <= 0;
                end
        end else if (commit_ifc.irf_select) begin
                x[commit_ifc.dest] <= commit_ifc.value;
        end
end
endmodule
