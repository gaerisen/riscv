`timescale 1ps / 1ps

// ROB functions:
//
// (1): FIFO for instruction commits; get new entries from decode, get updates
// from execute, then broadcast details of HEAD every writeback
//
// (2): Writeback buffer; store register and memory wb values early and notify
// the pipeline if an operand is available for forwarding

module rob
import rv32::*;
#(
        parameter int ROB_LEN = 32
)(
        input clk,
        input rst,

        // From issue/ex regs
        input issue,
        input [31:0] issued_dest,
        input ctrl_t issued_ctrl,

        // Broadcast ROB entry ptr for the instruction just issued so the
        // pipeline can update the right entry later
        output logic [$clog2(ROB_LEN)-1:0] issued_ptr,
        
        // From exe
        input update_entry,
        input [31:0] result,
        input [$clog2(ROB_LEN)-1:0] entry_idx,

        output logic commit,
        output logic store,
        output logic branch,
        output logic [31:0] rd,
        output logic [31:0] wb
);

rob_entry_t rob [ROB_LEN-1:0];

rob_entry_t rob_issue_next;
rob_entry_t rob_update_next;

logic [$clog2(ROB_LEN)-1:0] rob_head;
logic [$clog2(ROB_LEN)-1:0] rob_head_next;

logic [$clog2(ROB_LEN)-1:0] rob_tail;
logic [$clog2(ROB_LEN)-1:0] rob_tail_next;

assign commit = rob[rob_head].ready;
assign store = rob[rob_head].ctrl_word.store;
assign branch = rob[rob_head].ctrl_word.branch;
assign rd = rob[rob_head].dest;
assign wb = rob[rob_head].value;

initial begin
        $dumpfile("rob.vcd");
        $dumpvars(0, rob);
end

// ROB pointer update logic
always_comb
begin
        rob_head_next = rob_head;
        rob_tail_next = rob_tail;

        if (commit && (rob_tail != rob_head + 1)) begin
                rob_head_next = rob_head + 1;
        end

        if (issue) begin
                rob_tail_next = rob_tail + 1;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                rob_tail <= 0;
                rob_head <= 0;
        end
        else begin
                rob_tail <= rob_tail_next;
                rob_head <= rob_head_next;

                if (issue)
                        issued_ptr <= rob_tail;
                else
                        issued_ptr <= 0;
        end
end

// ROB issue write logic
always_comb
begin
        rob_issue_next.ctrl_word = 0;
        rob_issue_next.dest = 0;
        rob_issue_next.value = 0;
        rob_issue_next.ready = 0;

        if (issue) begin
                rob_issue_next.ctrl_word = issued_ctrl;
                rob_issue_next.dest = issued_dest;
        end
end

// ROB update logic
always_comb
begin
        rob_update_next = rob[entry_idx];

        if (update_entry) begin
                rob_update_next.value = result;
                rob_update_next.ready = 1;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < ROB_LEN; i++) begin
                        rob[i] <= 0;
                end
        end
        else begin
                rob[rob_tail] <= rob_issue_next;
                rob[entry_idx] <= rob_update_next;
        end
end

endmodule // rob
