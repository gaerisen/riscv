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

        issue_ifc.rob issue_ifc,
        
        cdb_ifc.rob cdb_ifc,

        commit_ifc.rob commit_ifc
);

rob_entry_t rob [ROB_LEN-1:0];
rob_entry_t rob_next [ROB_LEN-1:0];

logic [ROB_BITS-1:0] rob_head;
logic [ROB_BITS-1:0] rob_head_next;

logic [ROB_BITS-1:0] rob_tail;
logic [ROB_BITS-1:0] rob_tail_next;

logic full;

logic issued_is_system;
logic committed_is_system;
logic sys_in_flight;
logic sys_in_flight_state;

logic [31:0] pc; // For debugging

assign commit_ifc.commit = rob[rob_head].ready;

assign cdb_ifc.speculation_meta = rob[cdb_ifc.tag].speculation_meta;

// Commit logic

always_comb
begin
        if (commit_ifc.commit) begin
                commit_ifc.store = rob[rob_head].ctrl_word.store;
                commit_ifc.branch = rob[rob_head].ctrl_word.branch;
                commit_ifc.exception = rob[rob_head].ctrl_word.exception;
                commit_ifc.trap_cause = rob[rob_head].ctrl_word.trap_cause;
                commit_ifc.trapret = rob[rob_head].ctrl_word.trapret;
                commit_ifc.dest = rob[rob_head].prd;
                commit_ifc.dest_old = rob[rob_head].prd_old;
                commit_ifc.value = rob[rob_head].value;
                commit_ifc.csr_dest = rob[rob_head].csrd;
                commit_ifc.csr_val = rob[rob_head].csr_val;
                pc = rob[rob_head].pc;
        end
        else begin
                commit_ifc.store = 0;
                commit_ifc.branch = 0;
                commit_ifc.exception = 0;
                commit_ifc.trap_cause = ILLEGAL;
                commit_ifc.trapret = 0;
                commit_ifc.dest = 0;
                commit_ifc.dest_old = 0;
                commit_ifc.value = 0;
                commit_ifc.csr_dest = 0;
                commit_ifc.csr_val = 0;
                pc = 0;
        end
end

// Stall logic
assign issued_is_system = issue_ifc.ctrl_word.exception | issue_ifc.ctrl_word.trapret |
                issue_ifc.ctrl_word.wfi | issue_ifc.ctrl_word.csr_we;

assign committed_is_system = rob[rob_head].ctrl_word.exception |
                                rob[rob_head].ctrl_word.trapret |
                                rob[rob_head].ctrl_word.wfi |
                                rob[rob_head].ctrl_word.csr_we;

always_comb
begin
        if (sys_in_flight_state) begin
                sys_in_flight = !(ctrl_ifc.flush | (commit_ifc.commit & committed_is_system));
        end
        else begin
                sys_in_flight = issue_ifc.issue & issued_is_system;
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


// Stall logic
assign full = rob_tail == (rob_head + {ROB_BITS{1'b1}});
assign ctrl_ifc.rob_stall = full | sys_in_flight;


always_ff @(posedge clk or posedge rst)
begin
        if (cdb_ifc.misspec) begin
                ctrl_ifc.rat = rob[ctrl_ifc.tag].rat;
                ctrl_ifc.free_list = rob[ctrl_ifc.tag].free_list;
                ctrl_ifc.free_head = rob[ctrl_ifc.tag].free_head;
                ctrl_ifc.free_tail = rob[ctrl_ifc.tag].free_tail;
        end
end

initial begin
        $dumpfile("rob.vcd");
        $dumpvars(0, rob);
end

assign issue_ifc.tag = rob_tail;

// ROB pointer update logic
always_comb
begin
        rob_head_next = rob_head;
        rob_tail_next = rob_tail;

        if (commit_ifc.commit) begin
                rob_head_next = rob_head + 1;
        end

        if (issue_ifc.issue & ~ctrl_ifc.flush) begin
                rob_tail_next = rob_tail + 1;
        end

        if (cdb_ifc.misspec) begin
                rob_tail_next = cdb_ifc.tag + 1;
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
        end
end

// ROB write logic
always_comb
begin
        rob_next = rob;

        if (issue_ifc.issue & ~ctrl_ifc.flush) begin
                rob_next[rob_tail] = 0;
                rob_next[rob_tail].ctrl_word = issue_ifc.ctrl_word;
                rob_next[rob_tail].pc = issue_ifc.pc;
                rob_next[rob_tail].rat = issue_ifc.rat;
                rob_next[rob_tail].free_head = issue_ifc.free_head;
                rob_next[rob_tail].speculation_meta = issue_ifc.speculation_meta;
        end

        if (cdb_ifc.update & ~rob[cdb_ifc.tag].flush) begin
                rob_next[cdb_ifc.tag].prd = cdb_ifc.dest;
                rob_next[cdb_ifc.tag].prd_old = cdb_ifc.dest_old;
                rob_next[cdb_ifc.tag].value = cdb_ifc.value;
                rob_next[cdb_ifc.tag].csrd = cdb_ifc.csrd;
                rob_next[cdb_ifc.tag].csr_val = cdb_ifc.csr_result;
                rob_next[cdb_ifc.tag].ready = 1;
        end

        if (cdb_ifc.misspec) begin
                for (logic [ROB_BITS-1:0] i = cdb_ifc.tag + 1; i != rob_tail; i++) begin
                        rob_next[i] = 0;
                        rob_next[i].flush = 1;
                end
        end

        if (commit_ifc.commit) begin
                rob_next[rob_head] = 0;
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
                rob <= rob_next;
        end
end

endmodule // rob
