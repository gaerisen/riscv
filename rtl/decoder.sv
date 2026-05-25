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

        output ctrl_t ctrl_o
);

instr_t instr;
logic [4:0] rs1_next;
logic [4:0] rs2_next;
logic [31:0] imm_next;
logic [4:0] rd_next;
ctrl_t ctrl_next;

// Pack raw instruction into union struct
assign instr = instr_i;

// Extract register identifiers (always same location)
assign rs1_next = instr.r.rs1;
assign rs2_next = instr.r.rs2;
assign rd_next = instr.r.rd;

// Extract opcode
assign ctrl_next.opcode = opcode_e'(instr.r.opcode);

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
        ctrl_next.load_op = LW;
        ctrl_next.store_op = SW;

        unique case (opcode_e'(instr.r.opcode))
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
                        imm_next[20] = instr.j.imm20;
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
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.jump = 1;

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = PC4;
                end

                BRANCH: begin
                        imm_next[12] = instr.b.imm12;
                        imm_next[11] = instr.b.imm11;
                        imm_next[10:5] = instr.b.imm10_5;
                        imm_next[4:1] = instr.b.imm4_1;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = PC;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.branch = 1;
                        ctrl_next.branch_op = branch_funct3_e'(instr.b.funct3);
                end

                LOAD: begin
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.load = 1;
                        ctrl_next.load_op = load_funct3_e'(instr.i.funct3);
                end

                STORE: begin
                        imm_next[11:5] = instr.s.imm11_5;
                        imm_next[4:0] = instr.s.imm4_0;

                        ctrl_next.alu_op = ADDSUB;
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.store = 1;
                        ctrl_next.store_op = store_funct3_e'(instr.s.funct3);

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = MEM;
                end

                ALUI: begin
                        imm_next[11:0] = instr.i.imm11_0;

                        ctrl_next.alu_op = alu_funct3_e'(instr.i.funct3);
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = IMM;

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = ALU;
                end

                ALUR: begin
                        ctrl_next.alu_op = alu_funct3_e'(instr.i.funct3);
                        ctrl_next.alu_src1 = RS1;
                        ctrl_next.alu_src2 = RS2;

                        ctrl_next.wb = 1;
                        ctrl_next.wb_src = ALU;
                end

                FENCE:;         // Single-core system; leaving as NOP for now
                SYSTEM:;        // TODO: Add ctrl signalling
        endcase // instr.r.opcode
end

// Save outputs to pipeline registers
always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                ctrl_o.opcode <= ALUI;
                ctrl_o.alu_op <= ADDSUB;
                rs1_o <= 0;
                rs2_o <= 0;
                imm_o <= 0;
                rd_o <= 0;
        end else if (~stall) begin
                ctrl_o <= ctrl_next;
                rs1_o <= rs1_next;
                rs2_o <= rs2_next;
                imm_o <= imm_next;
                rd_o <= rd_next;
        end
end

endmodule: decoder
