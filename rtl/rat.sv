`timescale 1ps / 1ps

module rat
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE),

        localparam int FREE_SIZE = PRF_SIZE - 32,
        localparam int FREE_BITS = $clog2(FREE_SIZE)
)(
        input clk,
        input rst,

        input [4:0] rs1,
        input [4:0] rs2,
        input [4:0] rd,

        output logic [PRF_BITS-1:0] prs1,
        output logic [PRF_BITS-1:0] prs2,
        output logic [PRF_BITS-1:0] prd_old,
        output logic [PRF_BITS-1:0] prd_new,

        input commit,
        input [PRF_BITS-1:0] free_prd
);

initial begin
        $dumpfile("rat.vcd");
        $dumpvars(0, rat);
end

logic [PRF_BITS-1:0] rat [0:31];
logic [PRF_BITS-1:0] free [0:FREE_SIZE-1];
logic [FREE_BITS-1:0] free_head;
logic [FREE_BITS-1:0] free_tail;
logic [FREE_BITS-1:0] free_head_next;
logic [FREE_BITS-1:0] free_tail_next;
logic [PRF_BITS-1:0] free_entry_next;

assign prs1 = rat[rs1];
assign prs2 = rat[rs2];
assign prd_old = rat[rd];

always_comb
begin
        free_head_next = free_head;
        free_tail_next = free_tail;
        free_entry_next = free[free_tail];
        prd_new = 0;

        if (rd != 0) begin
                free_head_next = free_head + 1;
                prd_new = free[free_head];
        end

        if (commit && free_prd != 0) begin
                free_tail_next = free_tail + 1;
                free_entry_next = free_prd;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                free_head <= 0;
                free_tail <= 0;
        end
        else begin
                free_head <= free_head_next;
                free_tail <= free_tail_next;
        end
end

// RAT and Free list update logic
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < 32; i++) begin
                        rat[i] <= i[5:0];
                end
                for (int i = 0; i < PRF_SIZE - 32; i++) begin
                        free[i] <= i[5:0] + 32;
                end
        end
        else begin
                rat[rd] <= prd_new;
                free[free_tail] <= free_entry_next;
        end
end

endmodule: rat
