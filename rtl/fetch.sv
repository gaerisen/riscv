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

        // Jump/branch signals (From EXE; PC - 2)
        input [31:0] pc_from_exe,
        input jump,
        input branch,
        input branch_taken,
        input [31:0] alu_result,

        // System control signals (From DEC; PC - 1)
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

typedef enum logic [2:0] {
        WAITING_IMEM,
        WAITING_IMEM_SPEC,
        WAITING_JALR,
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
logic inst_is_jump;
logic inst_is_call;
logic inst_is_ret;
logic inst_is_b;

logic [31:0] jump_target;

logic b_predict_taken;

// Prediction/target signals
logic [1:0] b_pred [0:255];
logic [31:0] btb [0:255];
logic [31:0] ras [0:7];
logic [2:0] ras_ptr;
logic [2:0] ras_ptr_next;


assign i_addr = pc_next;


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

assign ret_mispredicted = jump & (pc_from_dec != alu_result);

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
        if (rst)
                ras_ptr <= 0;
        else
                ras_ptr <= ras_ptr_next;
end

// Latch return addresses in RAS
always_latch
begin
        if (inst_is_call)
                ras[ras_ptr_next] = pc_o + 4;
end

//================================
//      BRANCH PREDICTOR
//================================

// Flag any issued branches
assign inst_is_b = (instr_o.b.opcode == BRANCH);

// Read branch predictor high bit for current PC
assign b_predict_taken = inst_is_b & b_pred[pc_o[9:2]][1];

assign b_mispredicted = branch & (pc_from_dec != alu_result);

// Update predictor and BTB for every branch executed
always_latch
begin
        if (branch & branch_taken) begin
                unique case (b_pred[pc_from_exe[9:2]])
                2'b00: b_pred[pc_from_exe[9:2]] = 2'b01;
                2'b01: b_pred[pc_from_exe[9:2]] = 2'b10;
                2'b10: b_pred[pc_from_exe[9:2]] = 2'b11;
                2'b11: b_pred[pc_from_exe[9:2]] = 2'b11;
                endcase
                
                btb[pc_from_exe[9:2]] = alu_result;
        end
        else if (branch & ~branch_taken) begin
                unique case (b_pred[pc_from_exe[9:2]])
                2'b00: b_pred[pc_from_exe[9:2]] = 2'b00;
                2'b01: b_pred[pc_from_exe[9:2]] = 2'b00;
                2'b10: b_pred[pc_from_exe[9:2]] = 2'b01;
                2'b11: b_pred[pc_from_exe[9:2]] = 2'b10;
                endcase
        end
end

//=================================
//      MAIN FETCH FSM
//=================================

// State switch logic
always_comb
begin
        // Stall-safe defaults
        pc_next = pc_o;
        instr_next = 0;
        valid_next = 0;
        flush_next = 0;
        state_next = state;

        if (~i_data_ready) begin
                if (state == SPECULATING) begin
                        if (
        end
        else begin
        end
        

        unique case (state)
        STREAMING: begin
                if (~i_data_ready) begin
                        instr_next = 0;
                        valid_next = 0;
                        state_next = WAITING_IMEM;

                // All following combinations SHOULD be mutually exclusive; each
                // relies on a unique opcode in current inst. Any order works.
                end
                else if (inst_is_jump) begin
                        pc_next = jump_target;  // Directly calculated -->
                                                // No speculation
                        if (~i_data_ready) begin
                                valid_next = 0;
                                instr_next = 0;
                                state_next = WAITING_IMEM;
                        end
                end
                else if (inst_is_b) begin
                        if (b_predict_taken) begin
                                pc_next = btb[pc_o[9:2]];
                        end

                        if (~i_data_ready) begin
                                valid_next = 0;
                                instr_next = 0;
                                state_next = WAITING_IMEM_SPEC;
                        end
                        else begin
                                state_next = SPECULATING;
                        end
                end
                else if (inst_is_ret) begin
                        pc_next = ras[ras_ptr];
                        if (~i_data_ready) begin
                                valid_next = 0;
                                instr_next = 0;
                                state_next = WAITING_IMEM_SPEC;
                        end
                        else begin
                                state_next = SPECULATING;
                        end

                // Must come after ret check; only stall if nothing to predict
                end
                else if (inst_is_jalr) begin
                        instr_next = 0;
                        valid_next = 0;
                        state_next = WAITING_JALR;
                end

        end

        WAITING_IMEM: begin
                if (i_data_ready) begin
                        state_next = STREAMING;
                end
                else begin
                        pc_next = pc_o;
                        instr_next = 0;
                        valid_next = 0;
                        state_next = WAITING_IMEM;
                end
        end

        WAITING_IMEM_SPEC: begin
                if (i_data_ready) begin
                        state_next = SPECULATING;
                end
                else begin
                        pc_next = pc_o;
                        instr_next = 0;
                        valid_next = 0;
                        state_next = WAITING_IMEM;
                end
        end

        WAITING_JALR: begin
                if (jump) begin
                        pc_next = alu_result;
                        if (~i_data_ready) begin
                                valid_next = 0;
                                instr_next = 0;
                                state_next = WAITING_IMEM;
                        end
                        else begin
                                state_next = STREAMING;
                        end
                end
                else begin
                        pc_next = pc_o;
                        instr_next = 0;
                        valid_next = 0;
                        state_next = WAITING_JALR;
                end
        end

        SPECULATING: begin
                if (~i_data_ready) begin
                        valid_next = 0;
                        instr_next = 0;
                        state_next = WAITING_IMEM_SPEC;
                end
                else if (branch & (pc_from_dec != alu_result)) begin // b_pred failed
                        pc_next = alu_result;
                        flush_next = 1;
                        if (~i_data_ready) begin
                                valid_next = 0;
                                instr_next = 0;
                                state_next = WAITING_IMEM;
                        end
                        else begin
                                valid_next = 1;
                                state_next = STREAMING;
                        end
                end
                else if (branch) begin // b_pred succeeded
                        if (~i_data_ready) begin
                                valid_next = 0;
                                instr_next = 0;
                                state_next = WAITING_IMEM;
                        end
                        else begin
                                valid_next = 1;
                                state_next = STREAMING;
                        end
                end
                else if (jump & (pc_from_dec != alu_result)) begin // ras failed
                end
                else if (jump) begin // ras succeeded
                        if (~i_data_ready) begin
                                valid_next = 0;
                                instr_next = 0;
                                state_next = WAITING_IMEM;
                        end
                        else begin
                                valid_next = 1;
                                state_next = STREAMING;
                        end
                end
                else begin // still speculating
                        // TODO: Stall if we hit another speculative instr
                        state_next = SPECULATING;
                end
        end
        endcase
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_o <= 0;
                instr_o <= 0;
                valid_o <= 0;
                flush_o <= 0;
                state <= STREAMING;
        end
        else begin
                pc_o <= pc_next;
                instr_o <= instr_next;
                valid_o <= valid_next;
                flush_o <= flush_next;
                state <= state_next;
        end
end

endmodule // fetch
