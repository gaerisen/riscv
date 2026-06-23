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

        // I-mem interface signals
        input i_data_ready,
        input [31:0] i_data,
        output logic [31:0] i_addr,

        // Control flow change signals
        global_ctrl_ifc.fetch ctrl_ifc,

        // Output to decode stage
        fet_to_dec_ifc.fetch fet_dec_ifc
);

typedef enum logic {
        STREAMING,
        STALLED
} state_e;

state_e state;
state_e state_next;

logic [31:0] pc_next;
logic [31:0] instr_next;
logic flush_next;
logic valid_next;

// Prediction signals
logic inst_is_jump;
logic inst_is_jalr;
logic inst_is_call;
logic inst_is_ret;
logic inst_is_b;

logic [31:0] jump_target;
logic [31:0] branch_target;

logic b_predict_taken;

logic speculating;
logic speculating_next;

// Prediction registers
logic [1:0] b_pred [0:B_PRED_SIZE-1];

logic [31:0] btb [0:BTB_SIZE-1];

logic [31:0] ras [0:RAS_SIZE-1];
logic [RAS_PTR_SIZE-1:0] ras_ptr;
logic [RAS_PTR_SIZE-1:0] ras_ptr_next;

// Slam IMEM with whatever's next
assign i_addr = pc_next;


//=================================
//      RETURN ADDRESS STACK
//=================================

// Flag any issued JAL(R)s
assign inst_is_jump = (fet_dec_ifc.instr.j.opcode == JAL);
assign inst_is_jalr = (fet_dec_ifc.instr.i.opcode == JALR);

// Flag JAL(R)s with rd==ra/x1 (calls)
assign inst_is_call = (inst_is_jump | inst_is_jalr) & (fet_dec_ifc.instr.j.rd == 1);

// Flag JALRs with rs1==ra/x1 (rets)
assign inst_is_ret = inst_is_jalr & (fet_dec_ifc.instr.i.rs1 == 1) &
                        (fet_dec_ifc.instr.i.imm11_0 == 0);

// Calculate jump targets
assign jump_target = fet_dec_ifc.pc + {{12{fet_dec_ifc.instr.j.imm20}}, fet_dec_ifc.instr.j.imm19_12,
                                fet_dec_ifc.instr.j.imm11, fet_dec_ifc.instr.j.imm10_1, 1'b0};


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
                        ras[ras_ptr_next] = fet_dec_ifc.pc + 4;
                end
        end

end

//================================
//      BRANCH PREDICTOR
//================================

// Flag any issued branches
assign inst_is_b = (fet_dec_ifc.instr.b.opcode == BRANCH);

// Calculate branch targets
assign branch_target = fet_dec_ifc.pc + {{20{fet_dec_ifc.instr.b.imm12}}, fet_dec_ifc.instr.b.imm11,
        fet_dec_ifc.instr.b.imm10_5, fet_dec_ifc.instr.b.imm4_1, 1'b0};

// Read branch predictor high bit for current PC
assign b_predict_taken = inst_is_b & b_pred[fet_dec_ifc.pc[B_PRED_PTR_SIZE+1:2]][1];

logic inc_predictor;
logic dec_predictor;

assign inc_predictor =  ctrl_ifc.branch_result_ready &
                        ctrl_ifc.speculation_meta.branch &
                        ctrl_ifc.branch_taken;

assign dec_predictor =  ctrl_ifc.branch_result_ready &
                        ctrl_ifc.speculation_meta.branch &
                        !ctrl_ifc.branch_taken;

// Update predictor whenever a branch is resolved
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < B_PRED_SIZE - 1; i++) begin
                        b_pred[i] <= 0;
                end
        end
        else begin
                if (inc_predictor) begin
                        unique case (b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]])
                        2'b00: b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]] = 2'b01;
                        2'b01: b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]] = 2'b10;
                        2'b10: b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]] = 2'b11;
                        2'b11: b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]] = 2'b11;
                        endcase
                end
                else if (dec_predictor) begin
                        unique case (b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]])
                        2'b00: b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]] = 2'b00;
                        2'b01: b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]] = 2'b00;
                        2'b10: b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]] = 2'b01;
                        2'b11: b_pred[ctrl_ifc.branch_pc[B_PRED_PTR_SIZE+1:2]] = 2'b10;
                        endcase
                end
        end
end

//=================================
//      BRANCH TARGET BUFFER
//=================================

logic update_btb;

assign update_btb =     ctrl_ifc.branch_result_ready & !ctrl_ifc.flush &
                        ctrl_ifc.speculation_meta.jump;

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
                if (update_btb) begin
                        btb[ctrl_ifc.branch_pc[BTB_PTR_SIZE+1:2]] = ctrl_ifc.branch_target;
                end
        end
end

//=================================
//      MAIN FETCH FSM
//=================================

logic stall;
assign stall = !i_data_ready | ctrl_ifc.stall;

logic j_mispredict;
logic b_mispredict_t;
logic b_mispredict_nt;

assign j_mispredict =   ctrl_ifc.branch_result_ready &
                        ctrl_ifc.speculation_meta.jump &
                        (ctrl_ifc.speculation_meta.target != ctrl_ifc.branch_target);

assign b_mispredict_t =         ctrl_ifc.branch_result_ready & !ctrl_ifc.flush &
                                ctrl_ifc.speculation_meta.branch &
                                ctrl_ifc.speculation_meta.branch_taken &
                                !ctrl_ifc.branch_taken;

assign b_mispredict_nt =        ctrl_ifc.branch_result_ready & !ctrl_ifc.flush &
                                ctrl_ifc.speculation_meta.branch &
                                !ctrl_ifc.speculation_meta.branch_taken &
                                ctrl_ifc.branch_taken;

// State switch logic
always_comb
begin
        // Stall-safe defaults
        pc_next = fet_dec_ifc.pc + 4;
        state_next = state;
        valid_next = fet_dec_ifc.valid;
        instr_next = i_data;
        fet_dec_ifc.speculation_meta = 0;

        speculating_next = speculating;
        flush_next = 0;

        unique case (state)
        STALLED: begin
                pc_next = fet_dec_ifc.pc;

                // Following three cases are delayed from issue by a few cycles;
                // -> redirects come from exception commits
                // -> mispredictions come from the execute stage
                // Therefore these should be serviced before we resolve whatever
                // we're waiting on here.
                if (ctrl_ifc.sys_redirect) begin
                        pc_next = ctrl_ifc.sys_vec;
                        speculating_next = 0;
                end

                if (j_mispredict | b_mispredict_nt) begin
                        pc_next = ctrl_ifc.branch_target;
                        flush_next = 1;
                        speculating_next = 0;
                end

                if (b_mispredict_t) begin
                        pc_next = ctrl_ifc.branch_pc + 4;
                        flush_next = 1;
                        speculating_next = 0;
                end

                // Doesn't matter how stall goes low; if it does, we're good
                if (!stall) begin
                        valid_next = 1;
                        state_next = STREAMING;
                end
        end

        STREAMING: begin
                // Next cases should all be mutually exclusive; each relies on a
                // unique opcode in current inst. Any order works.
                if (inst_is_jump) begin
                        pc_next = jump_target;
                end

                // All following are speculative
                else if (inst_is_b) begin
                        fet_dec_ifc.speculation_meta.branch = 1;
                        fet_dec_ifc.speculation_meta.branch_taken = b_predict_taken;

                        if (b_predict_taken) begin
                                fet_dec_ifc.speculation_meta.target = branch_target;
                                pc_next = branch_target;
                        end
                        else begin
                                fet_dec_ifc.speculation_meta.target = fet_dec_ifc.pc + 4;
                                pc_next = fet_dec_ifc.pc + 4;
                        end
                        speculating_next = 1;
                end
                else if (inst_is_ret) begin
                        fet_dec_ifc.speculation_meta.jump = 1;
                        fet_dec_ifc.speculation_meta.target = ras[ras_ptr];
                        pc_next = ras[ras_ptr];
                        speculating_next = 1;
                end
                // jalr-not-ret must come after jalr-is-ret
                else if (inst_is_jalr) begin
                        fet_dec_ifc.speculation_meta.jump = 1;
                        fet_dec_ifc.speculation_meta.target = btb[fet_dec_ifc.pc[BTB_PTR_SIZE+1:2]];
                        pc_next = btb[fet_dec_ifc.pc[BTB_PTR_SIZE+1:2]];
                        speculating_next = 1;
                end

                // If misprediction detected, redirect and flush pipeline
                if (j_mispredict | b_mispredict_nt) begin
                        pc_next = ctrl_ifc.branch_target;
                        flush_next = 1;
                        speculating_next = 0;
                end
                else if (b_mispredict_t) begin
                        pc_next = ctrl_ifc.branch_pc + 4;
                        flush_next = 1;
                        speculating_next = 0;
                end


                // Sys redirects clobber normal control flow
                if (ctrl_ifc.sys_redirect) begin
                        pc_next = ctrl_ifc.sys_vec;
                        flush_next = 1;
                        speculating_next = 0;
                end

                if (!i_data_ready) begin
                        valid_next = 0;
                        state_next = STALLED;
                end
                else if (ctrl_ifc.stall) begin
                        valid_next = 0;
                        pc_next = fet_dec_ifc.pc;
                        state_next = STALLED;
                end


                fet_dec_ifc.speculation_meta.speculative = speculating;
        end
        endcase
end

// Output flip-flops
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                fet_dec_ifc.pc <= 0;
                fet_dec_ifc.instr <= 32'h13;
                fet_dec_ifc.valid <= 0;

                ctrl_ifc.flush <= 0;

                speculating <= 0;
                state <= STALLED;
        end
        else begin
                fet_dec_ifc.pc <= pc_next;
                fet_dec_ifc.instr <= instr_next;
                fet_dec_ifc.valid <= valid_next;

                ctrl_ifc.flush <= flush_next;

                speculating <= speculating_next;
                state <= state_next;
        end

end

endmodule // fetch
