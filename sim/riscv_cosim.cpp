#include "riscv_cosim.hpp"
#include <iostream>

void parse(uint32_t instr, instr_t &result);
int32_t get_imm(instr_t instr);
alu_src_e get_alu_src (instr_t instr);
alu_f3_e get_alu_op (instr_t instr);
int32_t execute(ctrl_word_t ctrl_word);
bool branch_eval(branch_f3_e op, int32_t rs1, int32_t rs2);

namespace sim
{

rv32ui::rv32ui() :
        nextpc(0), pc(0), result(0), dest(0)
{
        for (int i = 0; i < 32; i++) {
                irf[i] = 0;
        }
}

rv32ui::~rv32ui() 
{}

void rv32ui::reset()
{
        nextpc = 0;
        pc = 0;
        result = 0;
        dest = 0;
        for (int i = 0; i < 32; i++) {
                irf[i] = 0;
        }
}

void rv32ui::eval(uint32_t instr)
{
        instr_t inst_word;

        opcode_e opcode;
        int32_t imm;
        ctrl_word_t ctrl_word;

        // Instruction decode
        parse(instr, inst_word);

        switch (get_alu_src(inst_word)) {
                case REG_REG:
                        ctrl_word.in1 = irf[inst_word.r.rs1];
                        ctrl_word.in2 = irf[inst_word.r.rs2];
                case REG_IMM:
                        ctrl_word.in1 = irf[inst_word.r.rs1];
                        ctrl_word.in2 = get_imm(inst_word);
                case ZERO_IMM:
                        ctrl_word.in1 = 0;
                        ctrl_word.in2 = get_imm(inst_word);
                case PC_IMM:
                        ctrl_word.in1 = nextpc;
                        ctrl_word.in2 = get_imm(inst_word);
                default:;
        }

        std::cout << std::hex << instr << " " << get_imm(inst_word) << std::endl;

        ctrl_word.op = get_alu_op(inst_word);

        ctrl_word.alt = inst_word.r.opcode == ALUR;
        ctrl_word.alt |= (inst_word.r.opcode == ALUI) && (ctrl_word.op == SR);
        ctrl_word.alt &= inst_word.r.funct7 == 0x20;

        int32_t value = execute(ctrl_word);
        bool branch_taken = branch_eval(static_cast<branch_f3_e>(inst_word.b.funct3),
                                irf[inst_word.r.rs1],
                                irf[inst_word.r.rs2]);

        // Execute and commit
        pc = nextpc;

        switch (inst_word.r.opcode) {
                case LOAD:
                case BRANCH:
                        result = 0;
                        break;
                case JAL:
                case JALR:
                        result = pc + 4;
                        break;
                case STORE:
                        result = irf[inst_word.r.rs2];
                        break;
                default:
                        result = value;
        }

        switch (inst_word.r.opcode) {
                case STORE:
                        dest = value;
                        break;
                case BRANCH:
                        dest = 0;
                        break;
                default:
                        dest = inst_word.r.rd;
        }

        switch (inst_word.r.opcode) {
                case JAL:
                case JALR:
                        nextpc = value;
                        break;
                case BRANCH:
                        nextpc = value;
                        if (branch_taken) break;
                default:
                        nextpc = pc + 4;
        }

        if ((inst_word.r.opcode != BRANCH) && (inst_word.r.opcode != STORE)) {
                irf[dest] = result;
                irf[0] = 0;
        }
}

}

void parse(uint32_t instr, instr_t &result)
{
        result.r.funct7 = f7(instr);
        result.r.rs2 = rs2(instr);
        result.r.rs1 = rs1(instr);
        result.r.funct3 = f3(instr);
        result.r.rd = rd(instr);
        result.r.opcode = opcode(instr);
}

alu_src_e get_alu_src (instr_t instr)
{
        alu_src_e src;

        switch (instr.r.opcode)
        {
                case LUI:
                        src = ZERO_IMM;
                        break;
                case AUIPC:
                case JAL:
                case JALR:
                case BRANCH:
                        src = PC_IMM;
                        break;
                case LOAD:
                case STORE:
                case ALUI:
                        src = REG_IMM;
                        break;
                default:
                        src = REG_REG;
        }

        return src;
}

int32_t get_imm(instr_t instr)
{
        int32_t imm;

        switch (instr.r.opcode) {
                case LUI: // uimm
                case AUIPC:
                        imm = instr.u.imm31_25 << 25;
                        imm |= instr.u.imm24_20 << 20;
                        imm |= instr.u.imm19_15 << 15;
                        imm |= instr.u.imm14_12 << 12;
                        break;
                case JAL: // jimm
                        imm = instr.j.imm20_and_10_5 << 25;
                        imm >>= 11;
                        imm &= 0xfff00000;
                        imm |= instr.j.imm19_15 << 15;
                        imm |= instr.j.imm14_12 << 12;
                        imm |= (instr.j.imm4_1_and_11 & 0x1) << 11;
                        imm |= (instr.j.imm20_and_10_5 & 0x3f) << 5;
                        imm |= instr.j.imm4_1_and_11 & 0x1e;
                        break;
                case JALR: // iimm
                case LOAD:
                case ALUI:
                        if ((instr.i.funct3 & 0x3) == 1) {
                                imm = instr.i.imm4_0;
                        } else {
                                imm = instr.i.imm11_5 << 25;
                                imm >>= 20;
                                imm |= instr.i.imm4_0;
                        }
                        break;
                case STORE: // simm
                        imm = instr.s.imm11_5 << 25;
                        imm >>= 20;
                        imm |= instr.s.imm4_0;
                        break;
                case BRANCH: // bimm
                        imm = instr.b.imm12_and_10_5 << 25;
                        imm >>= 19;
                        imm &= 0xfffff000;
                        imm |= (instr.b.imm4_1_and_11 & 0x1) << 11;
                        imm |= (instr.b.imm12_and_10_5 & 0x3f) << 5;
                        imm |= instr.b.imm4_1_and_11 & 0x17;
                        break;
                default: // no imm
                        imm = 0;
                        break;
        }

        return imm;
}

alu_f3_e get_alu_op(instr_t instr)
{
        alu_f3_e op;

        switch (instr.r.opcode) {
                case LUI:
                case AUIPC:
                case JAL:
                case JALR:
                case LOAD:
                case STORE:
                case BRANCH:
                        op = ADDSUB;
                        break;
                default: 
                        op = static_cast<alu_f3_e>(instr.r.funct3);
        }

        return op;
}

int32_t execute(ctrl_word_t ctrl_word)
{
        int32_t result;

        int32_t in1 = ctrl_word.in1;
        int32_t in2 = ctrl_word.in2;

        switch (ctrl_word.op) {
                case ADDSUB:
                        if (ctrl_word.alt) {
                                result = in1 - in2;
                        } else {
                                result = in1 + in2;
                        }
                case SLL:
                        result = in1 << in2;
                        break;
                case SLT:
                        result = in1 < in2;
                        break;
                case SLTU:
                        result = static_cast<uint32_t>(in1) < 
                                 static_cast<uint32_t>(in2);
                        break;
                case XOR:
                        result = in1 ^ in2;
                        break;
                case SR:
                        if (ctrl_word.alt) {
                                result = in1 >> in2;
                        } else {
                                result = static_cast<uint32_t>(in1) >>
                                         static_cast<uint32_t>(in2);
                        }
                        break;
                case OR:
                        result = in1 | in2;
                        break;
                case AND:
                        result = in1 & in2;
                default:;
        }

        return result;
}

bool branch_eval(branch_f3_e op, int32_t rs1, int32_t rs2)
{
        switch (op) {
                case BEQ: return rs1 == rs2;
                case BNE: return rs1 != rs2;
                case BLT: return rs1 < rs2;
                case BGE: return rs1 >= rs2;
                case BLTU: return static_cast<uint32_t>(rs1) < static_cast<uint32_t>(rs2);
                case BGEU: return static_cast<uint32_t>(rs1) >= static_cast<uint32_t>(rs2);
                default: return false;
        }
}
