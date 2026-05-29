module fetch
import rv32::*;
#()
(
        input clk,
        input rst,

        // I-mem interface signals
        input i_data_ready,
        input [31:0] i_data_i,

        output logic [31:0] i_addr,

        // Jump/branch signals
        input jump,
        input branch,
        input branch_taken,
        input [31:0] alu_result,

        // System control signals
        input system_t system_word,
        input [31:0] mtvec,
        input [31:0] mepc,

        // Output to decode stage
        output logic [31:0] pc_o,
        output logic [31:0] instr_o,
        output logic valid_o,
        output logic flush_o
);

typedef enum logic [1:0] {
        WAITING,
        STREAMING,
        SPECULATING
} state_e;

state_e state;
state_e state_next;

logic [31:0] pc_next;
logic [31:0] instr_next;
logic valid_next;
logic flush_next;

// Prediction signals
logic inst_is_b;
logic inst_is_ret;

logic b_predict_taken;
logic [31:0] pc_flush;

// Prediction/target signals
logic [1:0] b_pred [0:255];
logic [31:0] btb [0:255];
logic [31:0] ras [0:7];
logic [2:0] ras_ptr;


assign i_addr = pc_next; // Always be slamming the imem for whatever is next

// Flag any committed JALRs with rs1==ra
assign inst_is_ret = (instr_o[6:2] == 5'b11001) & (instr_o[19:15] == 1);

// Flag any committed branches
assign inst_is_b = (instr_o[6:2] == 5'b11000);

// Latch prediction when speculation begins, then clear when finished
always_latch
begin
        if (inst_is_b & (state == STREAMING)) begin
                b_predict_taken = (b_pred[pc_o[9:2]][1]);
                pc_flush = pc_o;
        end else if (branch) begin
                b_predict_taken = 0;
                pc_flush = 0;
        end
end

always_comb
begin
        pc_next = pc_o + 4;
        instr_next = i_data_i;
        valid_next = 1;
        flush_next = 0;
        state_next = STREAMING;

        unique case (state)
        STREAMING: begin
                if (~i_data_ready) begin
                        pc_next = pc_o;
                        instr_next = 0;
                        valid_next = 0;
                        state_next = WAITING;
                end else if (inst_is_b) begin
                        if (b_predict_taken)
                                pc_next = btb[pc_o[9:2]];
                        else
                                pc_next = pc_o + 4;

                        state_next = SPECULATING;
                end else if (inst_is_ret) begin
                        pc_next = ras[ras_ptr];
                        state_next = SPECULATING;
                end
        end

        WAITING: begin
                if (i_data_ready) begin
                        state_next = STREAMING;
                end else begin
                        pc_next = pc_o;
                        instr_next = 0;
                        valid_next = 0;
                end
        end

        SPECULATING: begin
                if (branch) begin
                        if (b_predict_taken != branch_taken) begin
                                pc_next = alu_result;
                                state_next = STREAMING;
                        end
                end
        end
        endcase
        pc_next = pc_o;
        instr_next = i_data_i;
        valid_next = i_data_ready;
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_o <= 0;
                instr_o <= 0;
                valid_o <= 0;
                flush_o <= 0;
                state <= STREAMING;
        end else begin
                pc_o <= pc_next;
                instr_o <= instr_next;
                valid_o <= valid_next;
                flush_o <= flush_next;
                state <= state_next;
        end
end

endmodule // fetch
