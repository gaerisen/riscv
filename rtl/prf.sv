`timescale 1ps / 1ps
module prf
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE)
)(
        input clk,
        input rst,

        // Read ports
        dispatch_ifc.prf dispatch_ifc,

        cdb_ifc.prf cdb_ifc,

        // Ready signals
        input [PRF_BITS-1:0] prd_new_from_rat,
        output logic [PRF_SIZE-1:0] prf_ready
);

logic [31:0] prf [0:PRF_SIZE-1];

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < PRF_SIZE; i++) begin
                        prf[i] <= 0;
                end

                dispatch_ifc.rs1_val <= 0;
                dispatch_ifc.rs2_val <= 0;
        end
        else if (cdb_ifc.dest != 0) begin
                prf[cdb_ifc.dest] <= cdb_ifc.value;

                dispatch_ifc.rs1_val <= prf[dispatch_ifc.prs1];
                dispatch_ifc.rs2_val <= prf[dispatch_ifc.prs2];
        end
end

// Ready signal logic
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin // Lowest order regs map directly to arch regs at reset
                prf_ready <= {{(PRF_SIZE-5){1'b0}}, 5'h1f};
        end
        else begin
                if (prd_new_from_rat != 0) begin
                        prf_ready[prd_new_from_rat] <= 0;
                end
                if (cdb_ifc.dest != 0) begin
                        prf_ready[cdb_ifc.dest] <= 1;
                end
        end
end

endmodule: prf
