#include "riscv_cosim.hpp"
#include <iostream>

int32_t get_imm(uint32_t instr);
alu_src_e get_alu_src (uint32_t instr);
alu_f3_e get_alu_op (uint32_t instr);
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
        opcode_e opcode;
        int32_t imm;
        ctrl_word_t ctrl_word;

        switch (get_alu_src(instr)) {
                case REG_REG:
                        ctrl_word.in1 = irf[rs1(instr)];
                        ctrl_word.in2 = irf[rs2(instr)];
                        break;
                case REG_IMM:
                        ctrl_word.in1 = irf[rs1(instr)];
                        ctrl_word.in2 = get_imm(instr);
                        break;
                case ZERO_IMM:
                        ctrl_word.in1 = 0;
                        ctrl_word.in2 = get_imm(instr);
                        break;
                case PC_IMM:
                        ctrl_word.in1 = nextpc;
                        ctrl_word.in2 = get_imm(instr);
                        break;
                default:;
        }

        ctrl_word.op = get_alu_op(instr);

        ctrl_word.alt = (opcode_e)opcode(instr) == ALUR;
        ctrl_word.alt |= ((opcode_e)opcode(instr) == ALUI) && (ctrl_word.op == SR);
        ctrl_word.alt &= f7(instr) == 0x20;

        int32_t value = execute(ctrl_word);
        bool branch_taken = branch_eval(static_cast<branch_f3_e>(f3(instr)),
                                irf[rs1(instr)],
                                irf[rs2(instr)]);

        // Execute and commit
        pc = nextpc;

        switch ((opcode_e)opcode(instr)) {
                case LOAD:
                case BRANCH:
                        result = 0;
                        break;
                case JAL:
                case JALR:
                        result = pc + 4;
                        break;
                case STORE:
                        result = irf[rs2(instr)];
                        break;
                default:
                        result = value; 
        }

        switch ((opcode_e)opcode(instr)) {
                case STORE:
                        dest = value;
                        break;
                case BRANCH:
                        dest = 0;
                        break;
                default:
                        dest = rd(instr);
        }

        switch ((opcode_e)opcode(instr)) {
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

        if (((opcode_e)opcode(instr) != BRANCH) && ((opcode_e)opcode(instr) != STORE)) {
                irf[dest] = result;
                irf[0] = 0;
        }

#ifdef DEBUG_COSIM
        std::cout << "pc: " << pc << ",\t";
        std::cout << "rs1(val): " << rs1(instr) << "(" << irf[rs1(instr)] << "),\t";
        std::cout << "rs2(val): " << rs2(instr) << "(" << irf[rs2(instr)] << "),\t";
        std::cout << "imm: " << get_imm(instr) << ",\t";
        std::cout << "result: " << result << "\n";
#endif
}

}

alu_src_e get_alu_src (uint32_t instr)
{
        switch ((opcode_e)opcode(instr))
        {
                case LUI:
                        return ZERO_IMM;
                case AUIPC:
                case JAL:
                case JALR:
                case BRANCH:
                        return PC_IMM;
                case LOAD:
                case STORE:
                case ALUI:
                        return REG_IMM;
                default:
                        return REG_REG;
        }
}

int32_t get_imm(uint32_t instr)
{
        int32_t imm;

        switch ((opcode_e)opcode(instr)) {
                case LUI: // uimm
                case AUIPC:
                        imm = f7(instr) << 25;
                        imm |= rs2(instr) << 20;
                        imm |= rs1(instr) << 15;
                        imm |= f3(instr) << 12;
                        break;
                case JAL: // jimm
                        imm = f7(instr) << 25;
                        imm >>= 11;
                        imm &= 0xfff00000;
                        imm |= rs1(instr) << 15;
                        imm |= f3(instr) << 12;
                        imm |= (rs2(instr) & 0x1) << 11;
                        imm |= (f7(instr) & 0x3f) << 5;
                        imm |= rs2(instr) & 0x1e;
                        break;
                case JALR: // iimm
                case LOAD:
                case ALUI:
                        if ((f3(instr) & 0x3) == 1) {
                                imm = rs2(instr);
                        } else {
                                imm = f7(instr) << 25;
                                imm >>= 20;
                                imm |= rs2(instr);
                        }
                        break;
                case STORE: // simm
                        imm = f7(instr) << 25;
                        imm >>= 20;
                        imm |= rd(instr);
                        break;
                case BRANCH: // bimm
                        imm = f7(instr) << 25;
                        imm >>= 19;
                        imm &= 0xfffff000;
                        imm |= (rd(instr) & 0x1) << 11;
                        imm |= (f7(instr) & 0x3f) << 5;
                        imm |= rd(instr) & 0x17;
                        break;
                default: // no imm
                        imm = 0;
                        break;
        }

        return imm;
}

alu_f3_e get_alu_op(uint32_t instr)
{
        alu_f3_e op;

        switch ((opcode_e)opcode(instr)) {
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
                        op = static_cast<alu_f3_e>(f3(instr));
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
