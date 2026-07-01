`timescale 1ps / 1ps

module rs
import rv32::*;
#(
        parameter int PRF_SIZE = 64,
        localparam int PRF_BITS = $clog2(PRF_SIZE),
        parameter int NUM_ENTRIES = 1,
//        localparam int ENTRIES_BITS = $clog2(NUM_ENTRIES),
        localparam int ENTRIES_BITS = 1,
        parameter int ROB_SIZE = 64,
        localparam int ROB_BITS = $clog2(ROB_SIZE)

)(
        input clk,
        input rst,

        global_ctrl_ifc.rs ctrl_ifc,

        issue_ifc.rs issue_ifc,

        cdb_ifc.rs cdb_ifc,

        dispatch_ifc.rs dispatch_ifc
);

rs_entry_t entries [NUM_ENTRIES-1:0];
rs_entry_t entries_next [NUM_ENTRIES-1:0];
rs_entry_t overflow_next;
rs_entry_t overflow;

logic [ENTRIES_BITS-1:0] fill_idx;
logic [ENTRIES_BITS-1:0] dispatch_idx;

logic dispatch_next;
ctrl_t ctrl_word_next;
logic [PRF_BITS-1:0] prd_old_next;
logic [PRF_BITS-1:0] prd_new_next;
logic [11:0] csrd_next;
logic [31:0] pc_next;
logic [31:0] imm_next;
logic [ROB_BITS-1:0] tag_next;

logic full;


// Entry selection
always_comb
begin
        dispatch_idx = 0;
        fill_idx = 0;

        dispatch_next = 0;

        for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (entries[i].full & entries[i].ready) begin
                        dispatch_idx = i[ENTRIES_BITS-1:0];
                        dispatch_next = 1;
                        break;
                end
        end

        if (dispatch_next) begin
                fill_idx = dispatch_idx;
        end
        else begin
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                        if (!entries[i].full) begin
                                fill_idx = i[ENTRIES_BITS-1:0];
                                break;
                        end
                end
        end

        full = !dispatch_next;

        for (int i = 0; i < NUM_ENTRIES; i++) begin
                full &= entries[i].full;
        end
end

assign ctrl_ifc.rs_stall = full;

// Dispatch
always_comb
begin
        // Signals needed for register read go out immediately
        dispatch_ifc.prs1 = 0;
        dispatch_ifc.prs2 = 0;
        dispatch_ifc.csrs = 0;

        // Signals not involved in register read go out as pipeline registers
        ctrl_word_next = 0;
        prd_new_next = 0;
        prd_old_next = 0;
        csrd_next = 0;
        pc_next = 0;
        imm_next = 0;
        tag_next = 0;

        if (dispatch_next) begin
                dispatch_ifc.prs1 = entries[dispatch_idx].prs1;
                dispatch_ifc.prs2 = entries[dispatch_idx].prs2;
                dispatch_ifc.csrs = entries[dispatch_idx].csrs;

                ctrl_word_next = entries[dispatch_idx].ctrl_word;
                prd_new_next = entries[dispatch_idx].prd_new;
                prd_old_next = entries[dispatch_idx].prd_old;
                csrd_next = entries[dispatch_idx].csrs;
                pc_next = entries[dispatch_idx].pc;
                imm_next = entries[dispatch_idx].imm;
                tag_next = entries[dispatch_idx].tag;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                dispatch_ifc.dispatch <= 0;
                dispatch_ifc.ctrl_word <= 0;
                dispatch_ifc.prd_new <= 0;
                dispatch_ifc.prd_old <= 0;
                dispatch_ifc.csrd <= 0;
                dispatch_ifc.pc <= 0;
                dispatch_ifc.imm <= 0;
                dispatch_ifc.tag <= 0;
        end
        else begin
                dispatch_ifc.dispatch <= dispatch_next;
                dispatch_ifc.ctrl_word <= ctrl_word_next;
                dispatch_ifc.prd_new <= prd_new_next;
                dispatch_ifc.prd_old <= prd_old_next;
                dispatch_ifc.csrd <= csrd_next;
                dispatch_ifc.pc <= pc_next;
                dispatch_ifc.imm <= imm_next;
                dispatch_ifc.tag <= tag_next;
        end
end
// New entry construction
always_comb
begin
        for (int i = 0; i < 8; i++) begin
                entries_next[i] = entries[i];
        end

        if (dispatch_next) begin
                entries_next[dispatch_idx].full = 0;
                if (overflow.full) begin
                        entries_next[fill_idx] = overflow;
                end
        end
        
        if (issue_ifc.issue & !full) begin
                entries_next[fill_idx].ctrl_word = issue_ifc.ctrl_word;
                entries_next[fill_idx].prs1 = issue_ifc.prs1;
                entries_next[fill_idx].prs2 = issue_ifc.prs2;
                entries_next[fill_idx].csrs = issue_ifc.csrs;
                entries_next[fill_idx].prd_old = issue_ifc.prd_old;
                entries_next[fill_idx].prd_new = issue_ifc.prd_new;
                entries_next[fill_idx].imm = issue_ifc.imm;
                entries_next[fill_idx].pc = issue_ifc.pc;
                entries_next[fill_idx].tag = issue_ifc.tag;

                unique case (issue_ifc.ctrl_word.alu_src)
                REG_REG: begin
                        entries_next[fill_idx].in1_ready = issue_ifc.preg_ready[issue_ifc.prs1];
                        entries_next[fill_idx].in2_ready = issue_ifc.preg_ready[issue_ifc.prs2];

                        if (cdb_ifc.update && (issue_ifc.prs1 == cdb_ifc.dest)) begin
                                entries_next[fill_idx].in1_ready = 1;
                        end

                        if (cdb_ifc.update && (issue_ifc.prs2 == cdb_ifc.dest)) begin
                                entries_next[fill_idx].in2_ready = 1;
                        end
                end
                REG_IMM: begin
                        entries_next[fill_idx].in1_ready = issue_ifc.preg_ready[issue_ifc.prs1];

                        if (cdb_ifc.update && (issue_ifc.prs1 == cdb_ifc.dest)) begin
                                entries_next[fill_idx].in1_ready = 1;
                        end

                        entries_next[fill_idx].in2_ready = 1;
                end
                ZERO_IMM: begin
                        entries_next[fill_idx].in1_ready = 1;
                        entries_next[fill_idx].in2_ready = 1;
                end
                PC_IMM: begin
                        entries_next[fill_idx].in1_ready = 1;
                        entries_next[fill_idx].in2_ready = 1;
                end
                endcase

                entries_next[fill_idx].full = 1;
                entries_next[fill_idx].ready = 
                                entries_next[fill_idx].in1_ready &
                                entries_next[fill_idx].in2_ready;
        end

        if (issue_ifc.issue & full) begin
                overflow_next.ctrl_word = issue_ifc.ctrl_word;
                overflow_next.prs1 = issue_ifc.prs1;
                overflow_next.prs2 = issue_ifc.prs2;
                overflow_next.csrs = issue_ifc.csrs;
                overflow_next.prd_old = issue_ifc.prd_old;
                overflow_next.prd_new = issue_ifc.prd_new;
                overflow_next.imm = issue_ifc.imm;
                overflow_next.pc = issue_ifc.pc;
                overflow_next.tag = issue_ifc.tag;

                unique case (issue_ifc.ctrl_word.alu_src)
                REG_REG: begin
                        overflow_next.in1_ready = issue_ifc.preg_ready[issue_ifc.prs1];
                        overflow_next.in2_ready = issue_ifc.preg_ready[issue_ifc.prs2];

                        if (cdb_ifc.update && (issue_ifc.prs1 == cdb_ifc.dest)) begin
                                overflow_next.in1_ready = 1;
                        end

                        if (cdb_ifc.update && (issue_ifc.prs2 == cdb_ifc.dest)) begin
                                overflow_next.in2_ready = 1;
                        end
                end
                REG_IMM: begin
                        overflow_next.in1_ready = issue_ifc.preg_ready[issue_ifc.prs1];

                        if (cdb_ifc.update && (issue_ifc.prs1 == cdb_ifc.dest)) begin
                                overflow_next.in1_ready = 1;
                        end

                        overflow_next.in2_ready = 1;
                end
                ZERO_IMM: begin
                        overflow_next.in1_ready = 1;
                        overflow_next.in2_ready = 1;
                end
                PC_IMM: begin
                        overflow_next.in1_ready = 1;
                        overflow_next.in2_ready = 1;
                end
                endcase

                overflow_next.full = 1;
                overflow_next.ready = 
                                overflow_next.in1_ready &
                                overflow_next.in2_ready;
        end
        else if (dispatch_next & !full) begin
                overflow_next = 0;
        end
        else begin
                overflow_next = overflow;
        end

        if (cdb_ifc.update) begin
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                        if (~entries_next[i].full) continue;
                        if (entries_next[i].prs1 == cdb_ifc.dest) begin
                                entries_next[i].in1_ready = 1;
                        end
                        if (entries_next[i].prs2 == cdb_ifc.dest) begin
                                entries_next[i].in2_ready = 1;
                        end
                        entries_next[i].ready = 
                                        entries_next[i].in1_ready &
                                        entries_next[i].in2_ready;
                end

                if (overflow_next.full) begin
                        if (overflow_next.prs1 == cdb_ifc.dest) begin
                                overflow_next.in1_ready = 1;
                        end
                        if (overflow_next.prs2 == cdb_ifc.dest) begin
                                overflow_next.in2_ready = 1;
                        end
                        overflow_next.ready = 
                                        overflow_next.in1_ready &
                                        overflow_next.in2_ready;
                end
        end
end

// Entry fill
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < NUM_ENTRIES; i++)
                        entries[i] <= 0;

                overflow <= 0;
        end
        else begin
                overflow <= overflow_next;
                for (int i = 0; i < NUM_ENTRIES; i++)
                        entries[i] <= entries_next[i];
        end
end

endmodule: rs
