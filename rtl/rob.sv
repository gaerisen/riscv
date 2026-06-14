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

        global_ctrl_ifc.rob ctrl_ifc,

        // From issue/ex regs
        input issue,
        input [31:0] issued_dest,
        input [11:0] issued_csr_dest,
        input ctrl_t issued_ctrl,
        input [31:0] issued_pc,

        // Broadcast ROB entry ptr for the instruction just issued so the
        // pipeline can update the right entry later
        output logic [ROB_BITS-1:0] issued_ptr,
        
        // From exe
        input update_entry,
        input [31:0] result,
        input [31:0] csr_result,
        input [31:0] updated_dest,
        input [ROB_BITS-1:0] entry_idx,

        fwding_ifc.commit fwd_ifc,

        output logic commit,
        output logic store,
        output logic branch,
        output logic exception,
        output logic trapret,
        output trap_cause_e trap_cause,
        output logic [31:0] rd,
        output logic [31:0] wb,
        output logic [11:0] csrd,
        output logic [31:0] csrwb
);

rob_entry_t rob [ROB_LEN-1:0];

rob_entry_t rob_issue_next;
rob_entry_t rob_update_next;

logic [ROB_BITS-1:0] rob_head;
logic [ROB_BITS-1:0] rob_head_next;

logic [ROB_BITS-1:0] rob_tail;
logic [ROB_BITS-1:0] rob_tail_next;

logic flush_internal;
logic full;

logic issued_is_system;
logic committed_is_system;
logic sys_in_flight;
logic sys_in_flight_state;

logic [31:0] pc; // For debugging


// Commit logic

assign commit = rob[rob_head].ready;

always_comb
begin
        if (commit) begin
                store = rob[rob_head].ctrl_word.store;
                branch = rob[rob_head].ctrl_word.branch;
                exception = rob[rob_head].ctrl_word.exception;
                trap_cause = rob[rob_head].ctrl_word.trap_cause;
                trapret = rob[rob_head].ctrl_word.trapret;
                rd = rob[rob_head].dest;
                wb = rob[rob_head].value;
                csrd = rob[rob_head].csr_dest;
                csrwb = rob[rob_head].csr_value;
                pc = rob[rob_head].pc;
        end
        else begin
                store = 0;
                branch = 0;
                exception = 0;
                trap_cause = ILLEGAL;
                trapret = 0;
                rd = 0;
                wb = 0;
                csrd = 0;
                csrwb = 0;
                pc = 0;
        end
end

// Forwarding
assign fwd_ifc.commit_val_valid = commit & !ctrl_ifc.flush;
assign fwd_ifc.rd_commit = rd[4:0];
assign fwd_ifc.commit_val = wb;


// Stall logic
assign issued_is_system = issued_ctrl.exception | issued_ctrl.trapret |
                issued_ctrl.wfi | issued_ctrl.csr_we;

assign committed_is_system = rob[rob_head].ctrl_word.exception |
                                rob[rob_head].ctrl_word.trapret |
                                rob[rob_head].ctrl_word.wfi |
                                rob[rob_head].ctrl_word.csr_we;

always_comb
begin
        if (sys_in_flight_state) begin
                sys_in_flight = !(ctrl_ifc.flush | (commit & committed_is_system));
        end
        else begin
                sys_in_flight = issue & issued_is_system;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                sys_in_flight_state <= 0;
        end
        else begin
                sys_in_flight_state <= sys_in_flight;
        end
end


assign full = rob_tail == (rob_head + {ROB_BITS{1'b1}});

assign ctrl_ifc.stall = full | sys_in_flight;

assign flush_internal = ctrl_ifc.flush | (commit & (trapret | exception));

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
        if (rst | flush_internal) begin
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
        rob_issue_next.csr_dest = issued_csr_dest;
        rob_issue_next.pc = issued_pc;

        rob_update_next = rob[entry_idx];

        rob_update_next.value = result;
        rob_update_next.csr_value = csr_result;
        rob_update_next.dest = updated_dest;
        rob_update_next.ready = 1;
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush_internal) begin
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
