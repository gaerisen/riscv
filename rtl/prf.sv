`timescale 1ps / 1ps
module prf
#(
        parameter int PRF_SIZE = 64
)(
        input clk,
        input rst,

        dispatch_ifc.prf dispatch_ifc,

        issue_ifc.prf issue_ifc,

        cdb_ifc.prf cdb_ifc
);

logic [31:0] prf [0:PRF_SIZE-1];

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < PRF_SIZE; i++) begin
                        prf[i] <= 0;
                end
        end
        else if (cdb_ifc.update && cdb_ifc.valid && (cdb_ifc.dest != 0)) begin
                prf[cdb_ifc.dest] <= cdb_ifc.value;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                issue_ifc.rs1_val <= 0;
                issue_ifc.rs2_val <= 0;
        end
        else begin
                issue_ifc.rs1_val <= prf[issue_ifc.prs1];
                issue_ifc.rs2_val <= prf[issue_ifc.prs2];
        end
end

logic [PRF_SIZE-1:0] preg_ready;
logic [PRF_SIZE-1:0] preg_ready_next;

always_comb
begin
        preg_ready_next = preg_ready;

        if (cdb_ifc.rollback) begin
                preg_ready_next = cdb_ifc.preg_ready | preg_ready;
        end

        if (cdb_ifc.update && (cdb_ifc.dest != 0)) begin
                preg_ready_next[cdb_ifc.dest] = preg_ready[cdb_ifc.dest] | cdb_ifc.valid;
        end

        if (dispatch_ifc.dispatch && (dispatch_ifc.prd_new != 0)) begin
                preg_ready_next[dispatch_ifc.prd_new] = 0;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                preg_ready <= {{{PRF_SIZE-32}{1'b0}}, 32'hffffffff};
        end
        else begin
                preg_ready <= preg_ready_next;
        end
end

assign dispatch_ifc.preg_ready = preg_ready;

endmodule: prf
