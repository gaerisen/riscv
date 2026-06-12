`timescale 1ps / 1ps

module decoder
import rv32::*;
#(
)(
        input clk,
        input rst,

        input logic [31:0] instr_i,

        output logic [31:0] imm_o,
        output logic [4:0] rd_o,

        output ctrl_t ctrl_o
);

instr_t instr;
logic [31:0] imm_next;
logic [4:0] rd_next;
ctrl_t ctrl_next;

// Pack raw instruction into union struct
assign instr = instr_i;

// Extract register identifiers (always same location)
assign rd_next = instr.r.rd;

// Combinational decode step
always_comb
begin
        // Default to NOP
        imm_next = 0;
        ctrl_next.alu_op = ADDSUB;
        ctrl_next.alu_src1 = ZERO;
        ctrl_next.alu_src2 = IMM;
        ctrl_next.branch = 0;
        ctrl_next.jump = 0;
        ctrl_next.load = 0;
        ctrl_next.store = 0;
        ctrl_next.exception = 0;
        ctrl_next.trapret = 0;
        ctrl_next.wfi = 0;
        ctrl_next.irf_we = 0;
        ctrl_next.csr_we = 0;
        ctrl_next.wb_src = WB_ALU;
        ctrl_next.branch_op = BEQ;
        ctrl_next.load_op = LB;
        ctrl_next.store_op = SB;
        ctrl_next.csr_op = CSRRW;
        ctrl_next.csr_src = NRS1;
        ctrl_next.alu_alt = NORM;
        ctrl_next.trap_cause = ILLEGAL; // In the decoder, almost all traps will
                                        // be illegal instrs, so it's
                                        // a reasonable default here. Will only
                                        // trigger if exception is set high.

        unique0 case (opcode_e'(instr.r.opcode)) // unique0 flags down instances
                                                // of multiple cases, but allows
                                                // for 0, allowing our illegal
                                                // fallback set above
                LUI: begin
                        imm_next[31:12] = instr.u.imm31_12;
                        
                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = ZERO;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.irf_we = 1;
                        ctrl_next.wb_src = WB_ALU;
                end

                AUIPC: begin
                        imm_next[31:12] = instr.u.imm31_12;
                        
                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = PC;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.irf_we = 1;
                        ctrl_next.wb_src = WB_ALU;
                end

                JAL: begin
                        imm_next[31:20] = {12{instr.j.imm20}};
                        imm_next[19:12] = instr.j.imm19_12;
                        imm_next[11] = instr.j.imm11;
                        imm_next[10:1] = instr.j.imm10_1;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = PC;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.jump = 1;

                        ctrl_next.irf_we = 1;
                        ctrl_next.wb_src = WB_PC4;
                end

                JALR: begin
                        imm_next[31:12] = {20{instr.i.imm11_0[11]}};
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.jump = 1;

                        ctrl_next.irf_we = 1;
                        ctrl_next.wb_src = WB_PC4;

                        if (instr.i.funct3 != 3'b000) begin
                                ctrl_next.exception = 1;
                        end
                end

                BRANCH: begin
                        imm_next[31:12] = {20{instr.b.imm12}};
                        imm_next[11] = instr.b.imm11;
                        imm_next[10:5] = instr.b.imm10_5;
                        imm_next[4:1] = instr.b.imm4_1;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = PC;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.branch = 1;
                        ctrl_next.branch_op = branch_funct3_e'(instr.b.funct3);

                        if (instr.b.funct3[2:1] == 2'b01) begin
                                ctrl_next.exception = 1;
                        end
                end

                LOAD: begin
                        imm_next[31:12] = {20{instr.i.imm11_0[11]}};
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.load = 1;
                        ctrl_next.load_op = load_funct3_e'(instr.i.funct3);

                        ctrl_next.irf_we = 1;
                        ctrl_next.wb_src = WB_MEM;

                        if (instr.i.funct3 == 3'b011 |
                                instr.i.funct3[2:1] == 2'b11)
                                ctrl_next.exception = 1;
                end

                STORE: begin
                        imm_next[31:12] = {20{instr.s.imm11_5[6]}};
                        imm_next[11:5] = instr.s.imm11_5;
                        imm_next[4:0] = instr.s.imm4_0;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.store = 1;
                        ctrl_next.store_op = store_funct3_e'(instr.s.funct3);

                        if (instr.s.funct3[2] | instr.s.funct3[1:0] == 2'b11)
                                ctrl_next.exception = 1;
                end

                ALUI: begin
                        imm_next[31:12] = {20{instr.i.imm11_0[11]}};
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = alu_funct3_e'(instr.i.funct3);
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        if (alu_funct3_e'(instr.i.funct3) == SR)
                                ctrl_next.alu_alt = alu_funct7_e'(instr.r.funct7);

                        ctrl_next.irf_we = 1;
                        ctrl_next.wb_src = WB_ALU;
                end

                ALUR: begin
                        if (instr.r.funct7 != NORM &
                                instr.r.funct7 != ALT)
                                ctrl_next.exception = 1;

                        ctrl_next.alu_alt = alu_funct7_e'(instr.r.funct7);
                        ctrl_next.alu_op = alu_funct3_e'(instr.i.funct3);
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = RS2;

                        ctrl_next.irf_we = 1;
                        ctrl_next.wb_src = WB_ALU;
                end

                FENCE: begin
                        if (instr.i.funct3 != 0)
                                ctrl_next.exception = 1;

                        ctrl_next.irf_we = 1; // Makes this a valid NOP
                end

                SYSTEM: begin 
                        if (instr.r.funct3 == 0) begin
                                if (instr.r.rs1 != 0 | instr.r.rd != 0) begin
                                        ctrl_next.exception = 1; 
                                        ctrl_next.trap_cause = ILLEGAL;
                                end
                                else if (instr.r.rs2 == 0 & instr.r.funct7 == 0) begin
                                        ctrl_next.exception = 1;
                                        ctrl_next.trap_cause = ECALL;
                                end
                                else if (instr.r.rs2 == 1 & instr.r.funct7 == 0) begin
                                        ctrl_next.exception = 1;
                                        ctrl_next.trap_cause = EBREAK;
                                end
                                else if (instr.r.rs2 == 2 & instr.r.funct7 == 8) begin
                                        ctrl_next.trapret = 1;
                                end
                                else if (instr.r.rs2 == 2 & instr.r.funct7 == 24) begin
                                        ctrl_next.trapret = 1;
                                end
                                else if (instr.r.rs2 == 5 & instr.r.funct7 == 8) begin
                                        ctrl_next.wfi = 1;
                                end
                                else begin
                                        ctrl_next.exception = 1; 
                                        ctrl_next.trap_cause = ILLEGAL;
                                end
                        end
                        else begin
                                ctrl_next.csr_op = csr_funct2_e'(instr.i.funct3[1:0]);
                                ctrl_next.csr_src = csr_src_e'(instr.i.funct3[2]);

                                imm_next = {27'b0, instr.i.rs1};

                                ctrl_next.csr_we = 1;
                                ctrl_next.irf_we = 1;
                                ctrl_next.wb_src = WB_CSR;
                        end
                end

                default: begin
                        ctrl_next.exception = 1; // ctrl word is NOP via starter logic
                                                      // above case
                end
        endcase // instr.r.opcode
end

// Save outputs to pipeline registers
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                ctrl_o <= 0;
                ctrl_o.irf_we <= 1;
                imm_o <= 0;
                rd_o <= 0;
        end else begin
                ctrl_o <= ctrl_next;
                imm_o <= imm_next;
                rd_o <= rd_next;
        end
end

endmodule: decoder
