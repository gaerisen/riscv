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
	parameter STQ_LEN = 64,
	parameter LDQ_LEN = 128,

	localparam STQ_BITS = $clog2(STQ_LEN),
	localparam LDQ_BITS = $clog2(LDQ_LEN)
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
        input commit_store,

	output logic mem_valid,
	output logic mem_we,
	output logic [31:0] mem_addr,
	output logic [31:0] mem_data_o,

        input mem_data_ready,
        input [31:0] mem_data_i,

        output logic full
);

initial begin
        $dumpfile("lsu.vcd");
        $dumpvars(0, lsu);
        end

stq_entry_t [STQ_LEN-1:0] stq;
logic [STQ_BITS-1:0] stq_head;
logic [STQ_BITS-1:0] stq_tail;

ldq_entry_t [LDQ_LEN-1:0] ldq;
logic [LDQ_BITS-1:0] ldq_head;
logic [LDQ_BITS-1:0] ldq_tail;

stq_entry_t [STQ_LEN-1:0] stq_next;
logic [STQ_BITS-1:0] stq_head_next;
logic [STQ_BITS-1:0] stq_tail_next;

ldq_entry_t [LDQ_LEN-1:0] ldq_next;
logic [LDQ_BITS-1:0] ldq_head_next;
logic [LDQ_BITS-1:0] ldq_tail_next;

logic st_en;
store_funct3_e st_op;
logic [31:0] st_addr;
logic [31:0] st_data;

logic st_en_next;
store_funct3_e st_op_next;
logic [31:0] st_addr_next;
logic [31:0] st_data_next;

logic ld_en;
logic [LDQ_BITS-1:0] ld_tag;
logic [31:0] ld_addr;

logic ld_en_next;
logic [LDQ_BITS-1:0] ld_tag_next;
logic [31:0] ld_addr_next;

logic update_next;
logic [5:0] update_tag_next;
logic [6:0] update_prd_next;
logic [31:0] update_data_next;

assign full = 	(ldq_tail == (ldq_head + {LDQ_BITS{1'b1}})) |
                (ldq_tail == (ldq_head + {{(LDQ_BITS-1){1'b1}}, 1'b0})) |
		(stq_tail == (stq_head + {STQ_BITS{1'b1}})) |
                (stq_tail == (stq_head + {{(STQ_BITS-1){1'b1}}, 1'b0}));

/* === Store scheduling and execution === 
* Extremely conservative. Only execute on commit. This means we can get away
* with only checking the head, since only the ROB head can commit and
* instructions are dispatched to both units in the same order
*/

always_comb
begin
        st_en_next = st_en;
        st_op_next = st_op;
        st_addr_next = st_addr;
        st_data_next = st_data;

	if (mem_we) begin
		st_en_next = 0;
		st_op_next = SB;
		st_addr_next = 0;
		st_data_next = 0;
	end

        if (stq[stq_head].data_valid) begin
                st_en_next = 1;
                st_op_next = stq[stq_head].st_op;
                st_addr_next = stq[stq_head].addr;
                st_data_next = stq[stq_head].data;
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
	ld_en_next = 0;
	ld_tag_next = 0;
	ld_addr_next = 0;
	
        // Unlike stores we need to preserve access state until data has arrived
        if (ld_en && !mem_data_ready) begin
                ld_en_next = ld_en;
                ld_addr_next = ld_addr;
                ld_tag_next = ld_tag;
        end
	if (ld_en && mem_data_ready) begin
		ld_en_next = 0;
		ld_addr_next = 0;
		ld_tag_next = 0;
	end
        else begin
                for (logic [LDQ_BITS-1:0] i = ldq_head; i != ldq_tail; i++) begin
                        if (ldq[i].addr_valid && !ldq[i].data_valid) begin
                                ld_en_next = 1;
                                ld_tag_next = i[LDQ_BITS-1:0];
                                ld_addr_next = ldq[i].addr;
                                break;
                        end
                end
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                ld_en <= 0;
                ld_addr <= 0;
                ld_tag <= 0;
        end
        else begin
                ld_en <= ld_en_next;
                ld_addr <= ld_addr_next;
                ld_tag <= ld_tag_next;
        end
end


/* === Load execution ===
* Distinct from scheduling; interacts with the CDB after memory access is done
*/
logic [FIFO_BITS-1:0] update_idx_next;
logic [FIFO_BITS-1:0] update_idx;

always_comb
begin
        update_next = 0;
        update_tag_next = 0;
        update_idx_next = 0;
        update_prd_next = 0;
        update_data_next = 0;

        for (logic [FIFO_BITS-1:0] i = fifo_head; i != fifo_tail; i++) begin
                if (!fifo[i].store && fifo[i].populated && !fifo[i].complete) begin
                        update_next = 1;
                        update_tag_next = fifo[i].tag;
                        update_idx_next = i;
                        update_prd_next = fifo[i].prd;
                        update_data_next = fifo[i].data;
			break;
                end
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                update <= 0;
                update_tag <= 0;
                update_idx <= 0;
                update_prd <= 0;
                update_data <= 0;
        end
        else begin
                update <= update_next;
                update_tag <= update_tag_next;
                update_idx <= update_idx_next;
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
        if (mem_we | fifo[fifo_head].complete)
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

        for (int i = 0; i < FIFO_LEN; i++) begin
                /* Generate Address 
                * Happens combinationally on issue. Since register read happens on issue
                * this is trivial, but may be a critical path later.
                */
                if (issue && fifo[i].valid && (issue_tag == fifo[i].tag)) begin
                        fifo_next[i].addr = rs1_val + imm;
                        if (fifo[i].store) fifo_next[i].data = rs2_val;
                        fifo_next[i].ready = 1;
                end
        end

        for (logic [FIFO_BITS-1:0] i = fifo_head; i != fifo_tail; i++) begin
                if (commit && commit_store && fifo[i].store && !fifo[i].populated) begin
                        fifo_next[i].populated = 1;
                        break;
                end
        end

        if (ld_en && mem_data_ready) begin
                fifo_next[ld_tag].data = mem_data_i;
                fifo_next[ld_tag].populated = 1;
        end

        if (ld_fwd_next) begin
                fifo_next[ld_fwd_tag].data = ld_fwd_data;
                fifo_next[ld_fwd_tag].populated = 1;
        end

        if (update) begin
                fifo_next[update_idx].complete = 1;
        end

        if (st_en_next | fifo[fifo_head].complete)
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


// Arbitrate loads and stores to shared memory bus
always_comb
begin
	mem_valid = 0;
	mem_we = 0;
	mem_addr = 0;
	mem_data_o = 0;

	// Static ld>st priority works very nicely right now since a gap is
	// inserted after every load. This may change
	if (ld_en) begin
		mem_valid = 1;
		mem_addr = ld_addr;
	end else if (st_en) begin
		mem_valid = 1;
		mem_we = 1;
		mem_addr = st_addr;
		mem_data_o = st_data;
	end
end
endmodule: lsu
