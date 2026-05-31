`timescale 1ps / 1ps

module fetch
import rv32::*;
#(
        parameter int RAS_SIZE = 8,
        parameter int RAS_PTR_SIZE = $clog2(RAS_SIZE),
        parameter int B_PRED_SIZE = 256,
        parameter int B_PRED_PTR_SIZE = $clog2(B_PRED_SIZE)
)(
        input clk,
        input rst,

        // I-mem interface signals
        input i_data_ready,
        input [31:0] i_data_i,

        output logic [31:0] i_addr,

        // Jump/branch signals (From EXE; pc_o - 2)
        input [31:0] pc_from_exe,
        input jump,
        input branch,
        input branch_taken,
        input [31:0] alu_result,

        // System control signals (From DEC; pc_o - 1)
        input [31:0] pc_from_dec,
        input system_t system_word,
        input [31:0] mtvec,
        input [31:0] mepc,

        // Output to decode stage
        output logic [31:0] pc_o,
        output instr_t instr_o,
        output logic valid_o,
        output logic flush_o
);

initial
begin
        $dumpfile("fetch.vcd");
        $dumpvars(0, fetch);
end

typedef enum logic [2:0] {
        RESET,
        WAITING_JALR,
        STREAMING,
        J_SPECULATING,
        B_SPECULATING
} state_e;

state_e state;
state_e state_next;

logic [31:0] pc_next;

logic [31:0] instr_next;
logic valid_next;
logic flush_next;

logic imem_stalling;

// Prediction signals
logic inst_is_jump;
logic inst_is_jalr;
logic inst_is_call;
logic inst_is_ret;
logic inst_is_b;

logic [31:0] jump_target;

logic b_predict_taken;

logic j_mispredict;
logic b_mispredict;

// Prediction registers
logic [1:0] b_pred [0:B_PRED_SIZE-1];
logic [31:0] btb [0:B_PRED_SIZE-1];

logic [31:0] ras [0:RAS_SIZE-1];
logic [RAS_PTR_SIZE-1:0] ras_ptr;
logic [RAS_PTR_SIZE-1:0] ras_ptr_next;

// Slam IMEM with whatever's next
assign i_addr = pc_next;

// Detect mispredictions
assign j_mispredict = (jump & (pc_from_dec != alu_result));

assign b_mispredict = 
                (branch & branch_taken & (pc_from_dec != alu_result)) |
                (branch & ~branch_taken & (pc_from_dec != (pc_from_exe + 4)));


//=================================
//      RETURN ADDRESS STACK
//=================================

// Flag any issued JALs
assign inst_is_jump = (instr_o.j.opcode == JAL);

// Flag JALs with rd==ra/x1 (calls)
assign inst_is_call = inst_is_jump & (instr_o.j.rd == 1);

// Calculate jump targets
assign jump_target = pc_o + {{12{instr_o.j.imm20}}, instr_o.j.imm19_12,
                                instr_o.j.imm11, instr_o.j.imm10_1, 1'b0};

// Flag any issued JALRs
assign inst_is_jalr = (instr_o.i.opcode == JALR);

assign inst_is_ret = inst_is_jalr & (instr_o.i.rs1 == 1) &
                        (instr_o.i.imm11_0 == 0);

// Push/pop on call/ret
always_comb
begin
        ras_ptr_next = ras_ptr;

        if (inst_is_call)
                ras_ptr_next = ras_ptr + 1;
        else if (inst_is_ret)
                ras_ptr_next = ras_ptr - 1;
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                ras_ptr <= 0;
                
                for (int i = 0; i < RAS_SIZE - 1; i++) begin
                        ras[i] <= 0;
                end
        end
        else begin
                ras_ptr <= ras_ptr_next;
                if (inst_is_call) begin
                        ras[ras_ptr_next] = pc_o + 4;
                end
        end

end

//================================
//      BRANCH PREDICTOR
//================================

// Flag any issued branches
assign inst_is_b = (instr_o.b.opcode == BRANCH);

// Read branch predictor high bit for current PC
assign b_predict_taken = inst_is_b & b_pred[pc_o[9:2]][1];

// Update predictor and BTB for every branch executed
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < B_PRED_SIZE - 1; i++) begin
                        b_pred[i] <= 0;
                        btb[i] <= 0;
                end
        end
        else begin
                if (branch & branch_taken) begin
                        unique case (b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]])
                        2'b00: b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = 2'b01;
                        2'b01: b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = 2'b10;
                        2'b10: b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = 2'b11;
                        2'b11: b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = 2'b11;
                        endcase
                        
                        btb[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = alu_result;
                end
                else if (branch & ~branch_taken) begin
                        unique case (b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]])
                        2'b00: b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = 2'b00;
                        2'b01: b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = 2'b00;
                        2'b10: b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = 2'b01;
                        2'b11: b_pred[pc_from_exe[B_PRED_PTR_SIZE+1:2]] = 2'b10;
                        endcase
                end
        end
end

//=================================
//      MAIN FETCH FSM
//=================================

// State switch logic
always_comb
begin
        // Stall-safe defaults
        pc_next = pc_o + 4;
        flush_next = 0;
        state_next = state;

        unique case (state)
        RESET: begin
                pc_next = 0;

                if (~rst)
                        state_next = STREAMING;
        end

        STREAMING: begin
                // Entry point for all redirects; if imem isn't ready, hold
                // i_addr at the redirect vector
                if (imem_stalling | rst) begin
                        pc_next = pc_o;
                end

                // Next cases should all be mutually exclusive; each relies on a
                // unique opcode in current inst. Any order works.
                else if (inst_is_jump) begin
                        pc_next = jump_target;  // Directly calculated. No spec
                end
                else if (inst_is_b) begin
                        if (b_predict_taken) begin
                                pc_next = btb[pc_o[9:2]];
                        end
                        state_next = B_SPECULATING;
                end
                else if (inst_is_ret) begin
                        pc_next = ras[ras_ptr];
                        state_next = J_SPECULATING;
                end
                // Must come after ret check; only stall if nothing to predict
                else if (inst_is_jalr) begin
                        state_next = WAITING_JALR;
                end

        end

        WAITING_JALR: begin
                if (jump) begin
                        pc_next = alu_result;
                        state_next = STREAMING;
                end
                // Spec checks in case we entered from SPECULATING. If this
                // condition never gets flagged, we know that speculation
                // succeeded, so the above exit point to STREAMING works.
                else if (j_mispredict | b_mispredict) begin
                        pc_next = alu_result;
                        flush_next = 1;
                        state_next = STREAMING;
                end
        end

        J_SPECULATING: begin
                // Speculation has failed
                if (j_mispredict) begin
                        pc_next = alu_result;
                        flush_next = 1;
                        state_next = STREAMING;
                end
                // Speculation completed successfully
                else begin
                        if (branch) begin
                                state_next = STREAMING;
                        end

                        // After speculation checks, behave exactly like STREAMING:
                        if (inst_is_jump) begin
                                pc_next = jump_target;  // Directly calculated. No spec
                        end
                        else if (inst_is_b) begin
                                if (b_predict_taken) begin
                                        pc_next = btb[pc_o[9:2]];
                                end
                                state_next = B_SPECULATING;
                        end
                        else if (inst_is_ret) begin
                                pc_next = ras[ras_ptr];
                                state_next = J_SPECULATING;
                        end
                        // Must come after ret check; only stall if nothing to predict
                        else if (inst_is_jalr) begin
                                state_next = WAITING_JALR;
                        end
                end
        end

        B_SPECULATING: begin
                // Speculation has failed
                if (b_mispredict) begin
                        pc_next = alu_result;
                        flush_next = 1;
                        state_next = STREAMING;
                end
                // Speculation completed successfully
                else begin
                        if (branch) begin
                                state_next = STREAMING;
                        end

                        // After speculation checks, behave exactly like STREAMING:
                        if (inst_is_jump) begin
                                pc_next = jump_target;  // Directly calculated. No spec
                        end
                        else if (inst_is_b) begin
                                if (b_predict_taken) begin
                                        pc_next = btb[pc_o[9:2]];
                                end
                                state_next = B_SPECULATING;
                        end
                        else if (inst_is_ret) begin
                                pc_next = ras[ras_ptr];
                                state_next = J_SPECULATING;
                        end
                        // Must come after ret check; only stall if nothing to predict
                        else if (inst_is_jalr) begin
                                state_next = WAITING_JALR;
                        end
                end
        end
        endcase

        // If system-level redirect, clobber FSM results completely
        if (system_word.illegal | system_word.ecall | system_word.ebreak) begin
                pc_next = mtvec;
                flush_next = 1;
                state_next = STREAMING;
        end
        else if (system_word.mret) begin
                pc_next = mepc;
                flush_next = 1;
                state_next = STREAMING;
        end

        // Instruction validity detection
        valid_next = 1;
        instr_next = i_data_i;

        if (~i_data_ready | state_next == WAITING_JALR) begin
                valid_next = 0;
                instr_next = 0;
        end
end

// Instruction validity detection
always_comb
begin
end

// Output flip-flops
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_o <= 0;
                instr_o <= 0;
                valid_o <= 0;
                flush_o <= 0;

                state <= RESET;
        end
        else begin
                pc_o <= pc_next;
                instr_o <= instr_next;
                valid_o <= valid_next;
                flush_o <= flush_next;

                state <= state_next;
        end

        imem_stalling <= ~i_data_ready;
end

endmodule // fetch
