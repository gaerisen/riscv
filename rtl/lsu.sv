`timescale 1ps / 1ps

/** Module: LSU (Load-Store Unit)
* Function: To execute & arbitrate loads and stores in the out-of-order pipeline
* Key components:
        * (1) FIFO store buffering. Sort of like a smaller, fatter ROB for
        * stores specifically. The ROB will trigger memory write on commit
        * (2) Load forwarding. If the store queue contains required data, pull
        * from here right away. (Needs to be strictly ordered. Maybe include
        * loads in the FIFO?)
        * (3) Actual memory accesses. Stores get completed on commit and popped
        * from the FIFO. Loads get completed right away if forwarding fails and
        * doesn't resolve until memory does.
*/
module lsu
import rv32::*;
#(
        parameter int FIFO_LEN = 8,
        localparam int FIFO_BITS = $clog2(FIFO_LEN)
)(
        input clk,
        input rst,

        // Dispatch interface
        input dispatch,
        input [5:0] dispatch_tag,
        input [6:0] new_prd,
        input ctrl_t ctrl_word,

        // Issue interface
        input issue,
        input [5:0] issue_tag,
        input [31:0] rs1_val,
        input [31:0] rs2_val,
        input [31:0] imm,

        // CDB interface (loads only)
        output logic update,
        output logic [5:0] update_tag,
        output logic [6:0] update_prd,
        output logic [31:0] update_data,

        // Commit interface (stores only)
        input commit,
        input [5:0] commit_tag,

        // DMEM load interface
        output logic ld_en,
        output logic [31:0] ld_addr,
        input ld_ready,
        input [31:0] ld_data,

        // DMEM store interface
        output logic st_en,
        output store_funct3_e st_op,
        output logic [31:0] st_addr,
        output logic [31:0] st_data
);

lsu_entry_t fifo [FIFO_LEN];
logic [FIFO_BITS-1:0] fifo_head;
logic [FIFO_BITS-1:0] fifo_tail;

lsu_entry_t fifo_next [FIFO_LEN];
logic [FIFO_BITS-1:0] fifo_head_next;
logic [FIFO_BITS-1:0] fifo_tail_next;

logic st_en_next;
store_funct3_e st_op_next;
logic [31:0] st_addr_next;
logic [31:0] st_data_next;

logic ld_en_next;
logic [FIFO_BITS-1:0] ld_tag;
logic [FIFO_BITS-1:0] ld_tag_next;
logic [31:0] ld_addr_next;

logic update_next;
logic [5:0] update_tag_next;
logic [6:0] update_prd_next;
logic [31:0] update_data_next;

/* === Store scheduling and execution === 
* Extremely conservative. Only execute on commit. This means we can get away
* with only checking the head, since only the ROB head can commit and
* instructions are dispatched to both units in the same order
*/

assign st_en_next = commit && (commit_tag == fifo[fifo_head].tag) &&
                        fifo[fifo_head].store;

always_comb
begin
        st_op_next = SB;
        st_addr_next = 0;
        st_data_next = 0;

        if (st_en_next) begin
                st_op_next = fifo[fifo_head].st_op;
                st_addr_next = fifo[fifo_head].addr;
                st_data_next = fifo[fifo_head].data;
        end
end
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                st_en <= 0;
                st_op <= SB;
                st_addr <= 0;
                st_data <= 0;
        end
        else begin
                st_en <= st_en_next;
                st_op <= st_op_next;
                st_addr <= st_addr_next;
                st_data <= st_data_next;
        end
end


/* === Load scheduling ===
* Much more aggressive than stores. If forwarded data is available, broadcast it
* immediately. If not, send the first available address to DMEM
*/

always_comb
begin
        // Unlike stores we need to preserve access state until data has arrived
        if (ld_en && !ld_ready) begin
                ld_en_next = ld_en;
                ld_addr_next = ld_addr;
                ld_tag_next = ld_tag;
        end
        else begin
                ld_en_next = 0;
                ld_tag_next = 0;
                ld_addr_next = 0;

                for (int i = 0; i < FIFO_LEN; i++) begin
                        if (fifo[i].store) break; // TODO: Do some speculation
                        if (fifo[i].ready) begin
                                ld_en_next = 1;
                                ld_tag_next = i[FIFO_BITS-1:0];
                                ld_addr_next = fifo[i].addr;
                        end
                end
        end
end

/* === Load execution ===
* Distinct from scheduling; interacts with the CDB after memory access is done
*/

always_comb
begin
        update_next = 0;
        update_tag_next = 0;
        update_prd_next = 0;
        update_data_next = 0;

        if (ld_en && ld_ready) begin
                update_next = 1;
                update_tag_next = fifo[ld_tag].tag;
                update_prd_next = fifo[ld_tag].prd;
                update_data_next = ld_data;
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                update <= 0;
                update_tag <= 0;
                update_prd <= 0;
                update_data <= 0;
        end
        else begin
                update <= update_next;
                update_tag <= update_tag_next;
                update_prd <= update_prd_next;
                update_data <= update_data_next;
        end
end


/* === FIFO update logic === */

// Tail update -- occurs at every dispatch
always_comb
begin
        fifo_tail_next = fifo_tail;

        if (dispatch && (ctrl_word.load || ctrl_word.store)) begin
                fifo_tail_next = fifo_tail + 1;
        end
end

// Head update -- occurs at every execute OR commit at the fifo head
always_comb
begin
        fifo_head_next = fifo_head;
        
        // Loads are marked ready only when data is captured and broadcasted
        // Stores must wait for commit, but st_en signals this already
        if ((!(fifo[fifo_head].store) && fifo[fifo_head].ready) || st_en_next)
                fifo_head_next = fifo_head + 1;
end

// Array update
always_comb
begin
        fifo_next = fifo;

        /* Populate */
        if (dispatch && (ctrl_word.load || ctrl_word.store)) begin
                fifo_next[fifo_tail].store = ctrl_word.store;
                if (ctrl_word.store) fifo_next[fifo_tail].st_op = ctrl_word.store_op;
                if (ctrl_word.load) fifo_next[fifo_tail].prd = new_prd;
                fifo_next[fifo_tail].tag = dispatch_tag;
                fifo_next[fifo_tail].valid = 1;
        end

        /* Generate Address 
        * Happens combinationally on issue. Since register read happens on issue
        * this is trivial, but may be a critical path later.
        */
        for (int i = 0; i < FIFO_BITS; i++) begin
                if (issue_tag == fifo[i].tag) begin
                        fifo_next[i].addr = rs1_val + imm;

                        if (fifo[i].store) fifo_next[i].data = rs2_val;

                        // Ready flag is for commit; stores are fine as soon as
                        // they have target addresses. Loads cannot go ready
                        // until they have data either from fwding or dmem.
                        fifo_next[i].ready = fifo[i].store;
                        break;
                end
        end

        if ((!fifo[fifo_head].store && fifo[fifo_head].ready) || st_en_next)
                fifo_next[fifo_head] = 0;
end


always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < FIFO_LEN; i++) begin
                        fifo[i] <= 0;
                end
                fifo_head <= 0;
                fifo_tail <= 0;
        end
        else begin
                fifo <= fifo_next;
                fifo_head <= fifo_head_next;
                fifo_tail <= fifo_tail_next;
        end
end

endmodule: lsu
