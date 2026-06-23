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

        input logic [PRF_SIZE-1:0] prf_ready,

        global_ctrl_ifc.rs ctrl_ifc,

        reserv_ifc.rs reserv_ifc,
        issue_ifc.rs issue_ifc,

        cdb_ifc.rs cdb_ifc,

        // Testing placeholder for dispatch
        dispatch_ifc.rs dispatch_ifc
);

rs_entry_t entries [NUM_ENTRIES-1:0];
rs_entry_t entries_next [NUM_ENTRIES-1:0];

logic [ENTRIES_BITS-1:0] fill_idx;
logic [ENTRIES_BITS-1:0] dispatch_idx;

logic dispatch_next;
ctrl_t ctrl_word_next;
logic [PRF_BITS-1:0] prd_old_next;
logic [PRF_BITS-1:0] prd_new_next;
logic [31:0] pc_next;
logic [31:0] imm_next;
logic [ROB_BITS-1:0] tag_next;
speculation_meta_t speculation_meta_next;

logic full;

assign ctrl_ifc.rs_stall = full;

// Entry selection
always_comb
begin
        dispatch_idx = 0;
        fill_idx = 0;

        dispatch_next = 0;
        full = 1;

        for (int i = 0; i < NUM_ENTRIES; i++) begin
                full = full & entries[i].full;
                if (!entries[i].full) begin
                        fill_idx = i[ENTRIES_BITS-1:0];
                        break;
                end
        end

        for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (entries[i].ready) begin
                        dispatch_idx = i[ENTRIES_BITS-1:0];
                        dispatch_next = 1;
                        break;
                end
        end
end

// Dispatch
always_comb
begin
        // Signals needed for register read go out immediately
        dispatch_ifc.prs1 = 0;
        dispatch_ifc.prs2 = 0;

        // Signals not involved in register read go out as pipeline registers
        ctrl_word_next = 0;
        prd_new_next = 0;
        prd_old_next = 0;
        pc_next = 0;
        imm_next = 0;
        tag_next = 0;
        speculation_meta_next = 0;

        if (dispatch_next) begin
                dispatch_ifc.prs1 = entries[dispatch_idx].prs1;
                dispatch_ifc.prs2 = entries[dispatch_idx].prs2;

                ctrl_word_next = entries[dispatch_idx].ctrl_word;
                prd_new_next = entries[dispatch_idx].prd_new;
                prd_old_next = entries[dispatch_idx].prd_old;
                pc_next = entries[dispatch_idx].pc;
                imm_next = entries[dispatch_idx].imm;
                tag_next = entries[dispatch_idx].tag;
                speculation_meta_next = entries[dispatch_idx].speculation_meta;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                dispatch_ifc.dispatch <= 0;
                dispatch_ifc.ctrl_word <= 0;
                dispatch_ifc.prd_new <= 0;
                dispatch_ifc.prd_old <= 0;
                dispatch_ifc.pc <= 0;
                dispatch_ifc.imm <= 0;
                dispatch_ifc.tag <= 0;
                dispatch_ifc.speculation_meta <= 0;
        end
        else begin
                dispatch_ifc.dispatch <= dispatch_next;
                dispatch_ifc.ctrl_word <= ctrl_word_next;
                dispatch_ifc.prd_new <= prd_new_next;
                dispatch_ifc.prd_old <= prd_old_next;
                dispatch_ifc.pc <= pc_next;
                dispatch_ifc.imm <= imm_next;
                dispatch_ifc.tag <= tag_next;
                dispatch_ifc.speculation_meta <= speculation_meta_next;
        end
end
// New entry construction
always_comb
begin
        for (int i = 0; i < 8; i++) begin
                entries_next[i] = entries[i];
        end

        if (dispatch_next) begin
                entries_next[dispatch_idx] = 0;
        end
        
        if (reserv_ifc.issue) begin
                entries_next[fill_idx].ctrl_word = reserv_ifc.ctrl_word;
                entries_next[fill_idx].prs1 = reserv_ifc.prs1;
                entries_next[fill_idx].prs2 = reserv_ifc.prs2;
                entries_next[fill_idx].prd_old = reserv_ifc.prd_old;
                entries_next[fill_idx].prd_new = reserv_ifc.prd_new;
                entries_next[fill_idx].imm = reserv_ifc.imm;
                entries_next[fill_idx].pc = reserv_ifc.pc;
                entries_next[fill_idx].tag = issue_ifc.tag + 1;
                entries_next[fill_idx].speculation_meta = reserv_ifc.speculation_meta;

                unique case (reserv_ifc.ctrl_word.alu_src)
                REG_REG: begin
                        entries_next[fill_idx].in1_ready = prf_ready[reserv_ifc.prs1];
                        entries_next[fill_idx].in2_ready = prf_ready[reserv_ifc.prs2];

                        if (cdb_ifc.update && reserv_ifc.prs1 == cdb_ifc.dest) begin
                                entries_next[fill_idx].in1_ready = 1;
                        end

                        if (cdb_ifc.update && reserv_ifc.prs2 == cdb_ifc.dest) begin
                                entries_next[fill_idx].in2_ready = 1;
                        end
                end
                REG_IMM: begin
                        entries_next[fill_idx].in1_ready = prf_ready[reserv_ifc.prs1];

                        if (cdb_ifc.update && reserv_ifc.prs1 == cdb_ifc.dest) begin
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
                                entries_next[fill_idx].in1_ready && 
                                entries_next[fill_idx].in2_ready;
        end

        if (cdb_ifc.update) begin
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                        if (entries[i].prs1 == cdb_ifc.dest) begin
                                entries_next[i].in1_ready = 1;
                        end
                        else if (entries[i].prs2 == cdb_ifc.dest) begin
                                entries_next[i].in2_ready = 1;
                        end
                        entries_next[i].ready = 
                                        entries_next[i].in1_ready && 
                                        entries_next[i].in2_ready;
                end
        end

        if (ctrl_ifc.flush) begin
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                        if (entries_next[i].speculation_meta.speculative) begin
                                entries_next[i] = 0;
                        end
                end
        end
end

// Entry fill
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < NUM_ENTRIES; i++)
                        entries[i] <= 0;
        end
        else begin
                for (int i = 0; i < NUM_ENTRIES; i++)
                        entries[i] <= entries_next[i];
        end
end

endmodule: rs
