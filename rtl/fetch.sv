`timescale 1ps / 1ps

module fetch
import rv32::*;
#(
        parameter int RAS_SIZE = 8,
        parameter int RAS_PTR_SIZE = $clog2(RAS_SIZE),
        parameter int B_PRED_SIZE = 256,
        parameter int B_PRED_PTR_SIZE = $clog2(B_PRED_SIZE),
        parameter int BTB_SIZE = 256,
        parameter int BTB_PTR_SIZE = $clog2(BTB_SIZE)
)(
        input clk,
        input rst,
        input stall,

        // I-mem interface signals
        input i_data_ready,
        input [31:0] i_data,

        output logic [31:0] i_addr,

        // Jump/branch signals (From EXE; pc_o - 2)
        input [31:0] pc_exe,
        input jump,
        input branch,
        input branch_taken,
        input [31:0] alu_result,

        // System control signals (From DEC; pc_o - 1)
        input [31:0] pc_dec,
        input sys_redirect,
        input [31:0] sys_vec,

        // Asynchronous flush signal
        output logic flush_o,

        // Output to decode stage
        output logic [31:0] pc_o,
        output instr_t instr_o,
        output logic valid_o
);

initial
begin
        $dumpfile("fetch.vcd");
        $dumpvars(0, fetch);
end

typedef enum logic {
        RESET,
        STREAMING
} state_e;

state_e state;
state_e state_next;

logic [31:0] pc_next;

logic [31:0] instr_next;
logic valid_next;

logic imem_stalling;

// Prediction signals
logic inst_is_jump;
logic inst_is_jalr;
logic inst_is_call;
logic inst_is_ret;
logic inst_is_b;

logic [31:0] jump_target;
logic [31:0] branch_target;

logic b_predict_taken;

logic j_mispredict;
logic b_mispredict_nt;
logic b_mispredict_t;

// Prediction registers
logic [1:0] b_pred [0:B_PRED_SIZE-1];

logic [31:0] btb [0:BTB_SIZE-1];

logic [31:0] ras [0:RAS_SIZE-1];
logic [RAS_PTR_SIZE-1:0] ras_ptr;
logic [RAS_PTR_SIZE-1:0] ras_ptr_next;

// Slam IMEM with whatever's next
assign i_addr = pc_next;

// Detect mispredictions
assign j_mispredict = (jump & (pc_dec != alu_result));
assign b_mispredict_nt = (branch & branch_taken & (pc_dec != alu_result));
assign b_mispredict_t = (branch & ~branch_taken & (pc_dec != (pc_exe + 4)));


//=================================
//      RETURN ADDRESS STACK
//=================================

// Flag any issued JAL(R)s
assign inst_is_jump = (instr_o.j.opcode == JAL);
assign inst_is_jalr = (instr_o.i.opcode == JALR);

// Flag JAL(R)s with rd==ra/x1 (calls)
assign inst_is_call = (inst_is_jump | inst_is_jalr) & (instr_o.j.rd == 1);

// Flag JALRs with rs1==ra/x1 (rets)
assign inst_is_ret = inst_is_jalr & (instr_o.i.rs1 == 1) &
                        (instr_o.i.imm11_0 == 0);

// Calculate jump targets
assign jump_target = pc_o + {{12{instr_o.j.imm20}}, instr_o.j.imm19_12,
                                instr_o.j.imm11, instr_o.j.imm10_1, 1'b0};


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

// Calculate branch targets
assign branch_target = pc_o + {{20{instr_o.b.imm12}}, instr_o.b.imm11,
        instr_o.b.imm10_5, instr_o.b.imm4_1, 1'b0};

// Read branch predictor high bit for current PC
assign b_predict_taken = inst_is_b & b_pred[pc_o[9:2]][1];

// Update predictor whenever a branch is resolved
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < B_PRED_SIZE - 1; i++) begin
                        b_pred[i] <= 0;
                end
        end
        else begin
                if (branch & branch_taken) begin
                        unique case (b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]])
                        2'b00: b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]] = 2'b01;
                        2'b01: b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]] = 2'b10;
                        2'b10: b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]] = 2'b11;
                        2'b11: b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]] = 2'b11;
                        endcase
                end
                else if (branch & ~branch_taken) begin
                        unique case (b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]])
                        2'b00: b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]] = 2'b00;
                        2'b01: b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]] = 2'b00;
                        2'b10: b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]] = 2'b01;
                        2'b11: b_pred[pc_exe[B_PRED_PTR_SIZE+1:2]] = 2'b10;
                        endcase
                end
        end
end

//=================================
//      BRANCH TARGET BUFFER
//=================================

always @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < BTB_SIZE - 1; i++) begin
                        btb[i] <= 0;
                end
        end
        else begin
                // For now, we'll update for every successful jump. If this
                // proves to be a problem, add signalling to only update with
                // targets from jalr-not-rets
                if (jump) begin
                        btb[pc_exe[BTB_PTR_SIZE+1:2]] = alu_result;
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
        state_next = state;

        flush_o = 0;

        unique case (state)
        RESET: begin
                pc_next = 0;

                if (~rst)
                        state_next = STREAMING;
        end

        STREAMING: begin
                // Entry point for all redirects; if imem isn't ready, hold
                // i_addr at the redirect vector
                if (stall | imem_stalling | rst) begin
                        pc_next = pc_o;
                end

                // If misprediction detected, redirect and flush pipeline
                if (j_mispredict | b_mispredict_nt) begin
                        pc_next = alu_result;
                        flush_o = 1;
                end
                else if (b_mispredict_t) begin
                        pc_next = pc_exe + 4;
                        flush_o = 1;
                end

                // Next cases should all be mutually exclusive; each relies on a
                // unique opcode in current inst. Any order works.
                else if (inst_is_jump) begin
                        pc_next = jump_target;
                end

                // All following are speculative
                else if (inst_is_b) begin
                        if (b_predict_taken) begin
                                pc_next = branch_target;
                        end
                end
                else if (inst_is_ret) begin
                        pc_next = ras[ras_ptr];
                end
                // jalr-not-ret must come after jalr-is-ret
                else if (inst_is_jalr) begin
                        pc_next = btb[pc_o[BTB_PTR_SIZE+1:2]];
                end

        end
        endcase

        // If system-level redirect, clobber FSM results completely
        if (sys_redirect) begin
                pc_next = sys_vec;
                flush_o = 1;
                state_next = STREAMING;
        end

        // Instruction validity detection
        valid_next = 1;
        instr_next = i_data;

        if (~i_data_ready) begin
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

                state <= RESET;
        end
        else begin
                pc_o <= pc_next;
                instr_o <= instr_next;
                valid_o <= valid_next;

                state <= state_next;
        end

        imem_stalling <= ~i_data_ready;
end

endmodule // fetch
