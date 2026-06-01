`timescale 1ps / 1ps

module decoder
import rv32::*;
#(
)(
        input clk,
        input rst,
        input flush,
        input stall,

        input logic [31:0] instr_i,

        output logic [4:0] rs1_o,
        output logic [4:0] rs2_o,
        output logic [31:0] imm_o,
        output logic [4:0] rd_o,

        output system_t system_o,

        output ctrl_t ctrl_o
);

instr_t instr;
logic [4:0] rs1_next;
logic [4:0] rs2_next;
logic [31:0] imm_next;
logic [4:0] rd_next;
system_t system_next;
ctrl_t ctrl_next;

// Pack raw instruction into union struct
assign instr = instr_i;

// Extract register identifiers (always same location)
assign rs1_next = instr.r.rs1;
assign rs2_next = instr.r.rs2;
assign rd_next = instr.r.rd;

initial
begin
        $dumpfile("decoder.vcd");
        $dumpvars(0, decoder);
end

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
        ctrl_next.wb = 0;
        ctrl_next.wb_src = ALU;
        ctrl_next.branch_op = BEQ;
        ctrl_next.load_op = LB;
        ctrl_next.store_op = SB;
        system_next.illegal = 0;
        system_next.ecall = 0;
        system_next.ebreak = 0;
        system_next.mret = 0;
        system_next.sret = 0;
        system_next.wfi = 0;

        unique0 case (opcode_e'(instr.r.opcode)) // unique0 flags down instances
                                                // of multiple cases, but allows
                                                // for 0, allowing our illegal
                                                // fallback set above
                LUI: begin
                        imm_next[31:12] = instr.u.imm31_12;
                        
                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = ZERO;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = ALU;
                end

                AUIPC: begin
                        imm_next[31:12] = instr.u.imm31_12;
                        
                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = PC;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = ALU;
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

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = PC4;
                end

                JALR: begin
                        imm_next[31:12] = {20{instr.i.imm11_0[11]}};
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.jump = 1;

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = PC4;

                        if (instr.i.funct3 != 3'b000)
                                system_next.illegal = 1;
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

                        if (instr.b.funct3[2:1] == 2'b01)
                                system_next.illegal = 1;
                end

                LOAD: begin
                        imm_next[31:12] = {20{instr.i.imm11_0[11]}};
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.load = 1;
                        ctrl_next.load_op = load_funct3_e'(instr.i.funct3);

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = MEM;

                        if (instr.i.funct3 == 3'b011 |
                                instr.i.funct3[2:1] == 2'b11)
                                system_next.illegal = 1;
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
                                system_next.illegal = 1;
                end

                ALUI: begin
                        imm_next[31:12] = {20{instr.i.imm11_0[11]}};
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = alu_funct3_e'(instr.i.funct3);
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = ALU;
                end

                ALUR: begin
                        if (instr.r.funct7 != NORM |
                                instr.r.funct7 != ALT)
                                system_next.illegal = 1;

                        ctrl_next.alu_op = alu_funct3_e'(instr.i.funct3);
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = RS2;

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = ALU;
                end

                FENCE: begin    // TODO: Make this not NOP
                        if (instr.i.funct3 != 0)
                                system_next.illegal = 1;
                end

                SYSTEM: begin   // TODO: Add Zicsr support
                        if (instr.r.funct3 != 0 |
                                instr.r.rd != 0 |
                                instr.r.rs1 != 0)
                                system_next.illegal = 1;

                        if (instr.r.rs2 == 0 & instr.r.funct7 == 0)
                                system_next.ecall = 1;
                        else if (instr.r.rs2 == 1 & instr.r.funct7 == 0)
                                system_next.ebreak = 1;
                        else if (instr.r.rs2 == 2 & instr.r.funct7 == 8)
                                system_next.mret = 1;
                        else if (instr.r.rs2 == 2 & instr.r.funct7 == 24)
                                system_next.sret = 1;
                        else if (instr.r.rs2 == 5 & instr.r.funct7 == 8)
                                system_next.wfi = 1;
                        else
                                system_next.illegal = 1;
                end

                default:
                        system_next.illegal = 1; // ctrl word is NOP via starter logic
                                        // above case
        endcase // instr.r.opcode
end

// Save outputs to pipeline registers
always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush | stall) begin
                ctrl_o.alu_op <= ADDSUB;
                system_o <= 0;
                rs1_o <= 0;
                rs2_o <= 0;
                imm_o <= 0;
                rd_o <= 0;
        end else begin
                ctrl_o <= ctrl_next;
                system_o <= system_next;
                rs1_o <= rs1_next;
                rs2_o <= rs2_next;
                imm_o <= imm_next;
                rd_o <= rd_next;
        end
end

endmodule: decoder
