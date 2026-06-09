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
        parameter int ROB_LEN = 64,
        localparam int ROB_BITS = $clog2(ROB_LEN)
)(
        input clk,
        input rst,

        // From fetch
        input flush_fet,

        output stall,

        // From issue/ex regs
        input issue,
        input [31:0] issued_dest,
        input ctrl_t issued_ctrl,
        input [31:0] issued_pc,

        // Broadcast ROB entry ptr for the instruction just issued so the
        // pipeline can update the right entry later
        output logic [ROB_BITS-1:0] issued_ptr,
        
        // From exe
        input update_entry,
        input [31:0] result,
        input [31:0] updated_dest,
        input [ROB_BITS-1:0] entry_idx,

        output logic commit,
        output logic store,
        output logic branch,
        output logic exception,
        output logic trapret,
        output trap_cause_e trap_cause,
        output logic [31:0] rd,
        output logic [31:0] wb
);

rob_entry_t rob [ROB_LEN-1:0];

rob_entry_t rob_issue_next;
rob_entry_t rob_update_next;

logic [ROB_BITS-1:0] rob_head;
logic [ROB_BITS-1:0] rob_head_next;

logic [ROB_BITS-1:0] rob_tail;
logic [ROB_BITS-1:0] rob_tail_next;

logic flush;

logic [31:0] pc; // For debugging
assign pc = rob[rob_head].pc;


assign commit = rob[rob_head].ready;
assign store = rob[rob_head].ctrl_word.store;
assign branch = rob[rob_head].ctrl_word.branch;
assign exception = rob[rob_head].ctrl_word.exception;
assign trap_cause = rob[rob_head].ctrl_word.trap_cause;
assign trapret = rob[rob_head].ctrl_word.trapret;
assign rd = rob[rob_head].dest;
assign wb = rob[rob_head].value;


// Stall logic
logic full;

/*
logic sys_in_flight;

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                sys_in_flight <= 0; 
        end
        else begin
                if (issued_system != 0) begin
                        sys_in_flight <= 1;
                end
                else if (commit & system != 0) begin
                        sys_in_flight <= 0;
                end
        end
end
*/

assign full = rob_tail == (rob_head + {ROB_BITS{1'b1}});

assign stall = full;

assign flush = flush_fet | (trapret | exception);

initial begin
        $dumpfile("rob.vcd");
        $dumpvars(0, rob);
end

// ROB pointer update logic
always_comb
begin
        rob_head_next = rob_head;
        rob_tail_next = rob_tail;

        if (commit) begin
                rob_head_next = rob_head + 1;
        end

        if (issue) begin
                rob_tail_next = rob_tail + 1;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
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

// ROB write logic
always_comb
begin
        rob_issue_next = 0;

        rob_issue_next.ctrl_word = issued_ctrl;
        rob_issue_next.dest = issued_dest;
        rob_issue_next.pc = issued_pc;

        rob_update_next = rob[entry_idx];

        rob_update_next.value = result;
        if (rob_update_next.ctrl_word.store)
                rob_update_next.dest = updated_dest;
        rob_update_next.ready = 1;
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                for (int i = 0; i < ROB_LEN; i++) begin
                        rob[i] <= 0;
                end
        end
        else begin
                if (update_entry) begin
                        rob[entry_idx] <= rob_update_next;
                end
                if (issue) begin
                        rob[rob_tail] <= rob_issue_next;
                end
                if (commit) begin
                        rob[rob_head] <= 0;
                end
        end
end

endmodule // rob
