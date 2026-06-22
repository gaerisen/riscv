`timescale 1ps / 1ps

module rs
import rv32::*;
#(
        parameter int NUM_ENTRIES = 4,
        localparam int ENTRIES_BITS = $clog2(NUM_ENTRIES)
)(
        input clk,
        input rst,

        // Testing placeholder for issue_ifc
        input issue,
        input [31:0] pc,
        input [31:0] imm,
        input [4:0] rs1,
        input [4:0] rs2,
        input [4:0] rd_i,
        input ctrl_t ctrl_word_i,
        
        // Testing placeholder for cdb_ifc
        input update,
        input [31:0] value,
        input [4:0] dest,

        // Testing placeholder for dispatch
        output logic dispatch,
        output ctrl_t ctrl_word_o,
        output logic [31:0] in1,
        output logic [31:0] in2,
        output logic [4:0] rd_o,

        output logic full
);

rs_entry_t entries [NUM_ENTRIES-1:0];
rs_entry_t entries_next [NUM_ENTRIES-1:0];

logic [ENTRIES_BITS-1:0] fill_idx;
logic [ENTRIES_BITS-1:0] dispatch_idx;

initial
begin
        $dumpfile("rs.vcd");
        $dumpvars(0, rs);
end

// Entry selection
always_comb
begin
        dispatch_idx = 0;
        fill_idx = 0;
        dispatch = 0;
        full = 0;

        for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (!entries[i].full) begin
                        fill_idx = i[ENTRIES_BITS-1:0];
                        break;
                end
                full = 1;
        end

        for (int i = 0; i < NUM_ENTRIES; i++) begin
                if (entries[i].ready) begin
                        dispatch_idx = i[ENTRIES_BITS-1:0];
                        dispatch = 1;
                        break;
                end
        end
end

// Dispatch
always_comb
begin
        ctrl_word_o = 0;
        in1 = 0;
        in2 = 0;
        rd_o = 0;

        if (dispatch) begin
                ctrl_word_o = entries[dispatch_idx].ctrl_word;
                in1 = entries[dispatch_idx].in1;
                in2 = entries[dispatch_idx].in2;
                rd_o = entries[dispatch_idx].rd;
        end
end

// New entry construction
always_comb
begin
        for (int i = 0; i < 8; i++) begin
                entries_next[i] = entries[i];
        end
        
        if (issue) begin
                entries_next[fill_idx].ctrl_word = ctrl_word_i;
                entries_next[fill_idx].rd = rd_i;

                unique case (ctrl_word_i.alu_src1)
                ZERO: begin
                        entries_next[fill_idx].in1_ready = 1;
                        entries_next[fill_idx].in1 = 0;
                end
                RS1: begin
                        entries_next[fill_idx].label1 = rs1;
                end
                PC: begin
                        entries_next[fill_idx].in1_ready = 1;
                        entries_next[fill_idx].in1 = pc;
                end
                endcase

                unique case (ctrl_word_i.alu_src2)
                RS2: begin
                        entries_next[fill_idx].label2 = rs2;
                end
                IMM: begin
                        entries_next[fill_idx].in2_ready = 1;
                        entries_next[fill_idx].in2 = imm;
                end
                endcase

                entries_next[fill_idx].full = 1;
                entries_next[fill_idx].ready = 
                                entries_next[fill_idx].in1_ready && 
                                entries_next[fill_idx].in2_ready;
        end

        if (update) begin
                for (int i = 0; i < NUM_ENTRIES; i++) begin
                        if (entries[i].label1 == dest) begin
                                entries_next[i].in1 = value;
                                entries_next[i].in1_ready = 1;
                        end
                        else if (entries[i].label2 == dest) begin
                                entries_next[i].in2 = value;
                                entries_next[i].in2_ready = 1;
                        end
                        entries_next[i].ready = 
                                        entries_next[i].in1_ready && 
                                        entries_next[i].in2_ready;
                end
        end

        if (dispatch) begin
                entries_next[dispatch_idx] = 0;
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
