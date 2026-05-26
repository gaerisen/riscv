#include "decoder.hpp"
#include "generator.hpp"
#include <iostream>
#include <iomanip>

// Instruction parsing macros
#define opcode(x) (x & 0b1111111)
#define rd(x) ((x & (0b11111 << 7)) >> 7)
#define f3(x) ((x & (0b111 << 12)) >> 12)
#define rs1(x) ((x & (0b11111 << 15)) >> 15)
#define rs2(x) ((x & (0b11111 << 20)) >> 20)
#define f7(x) ((x & (0b1111111 << 25)) >> 25)

// Ctrl word parsing macros
#define op(x) ((x & (0b11111 << 24)) >> 24)
#define src1(x) ((x & (0b11 << 22)) >> 22)
#define src2(x) ((x & (0b1 << 21)) >> 21)
#define af3(x) ((x & (0b111 << 16)) >> 16)
#define bf3(x) ((x & (0b111 << 13)) >> 13)
#define lf3(x) ((x & (0b111 << 10)) >> 10)
#define sf3(x) ((x & (0b111 << 7)) >> 7)
#define f7_ctrl(x) ((x & (0b1 << 5)) >> 5)

// System word parsing macros
#define illegal(x) ((x & 0b100000) >> 5)
#define ecall(x) ((x & 0b10000) >> 4)
#define ebreak(x) ((x & 0b1000) >> 3)
#define mret(x) ((x & 0b100) >> 2)
#define sret(x) ((x & 0b10) >> 1)
#define wfi(x) (x & 0b1)

namespace sim
{

int opcodes[] = {
        0b01101, // lui
        0b00101, // auipc
        0b11011, // jal
        0b11001, // jalr
        0b11000, // branch
        0b00000, // load
        0b01000, // store
        0b00100, // alui
        0b01100, // alur
        0b00011, // fence 
        0b11100  // system
};

decoder::decoder(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{
        dut->stall = 0;
        dut->flush = 0;
        dut->instr_i = 0;
}

decoder::~decoder()
{}

void decoder::stall(int n)
{
        dut->stall = 1;

        for (int i = 0; i < n; i++) {
                pulse();
        }

        dut->stall = 0;

        return;
}

void decoder::flush(int n)
{
        dut->flush = 1;

        for (int i = 0; i < n; i++) {
                pulse();
        }

        dut->flush = 0;

        return;
}

// Feeds the decoder `cycles` randomly generated instructions (with valid
// opcodes) and warns the user of any mismatches between the RTL's result and
// the result of the model contained in the function
void decoder::run_tests(int cycles)
{
        struct sim::generator gen;
        unsigned int instr;

        gen.add_field(1, 0, 3);
        gen.add_field(6, 2, opcodes, 11);
        gen.add_field(11, 7, 0, 31);
        gen.add_field(14, 12, 0, 7);
        gen.add_field(19, 15, 0, 31);
        gen.add_field(24, 20, 0, 31);
        gen.add_field(31, 25, 0, 127);

        reset(5);

        std::cout << "=== Begin Decoder Test ===" << std::endl;

        for (int i = 0; i < cycles; i++) {
                instr = gen.generate();

                std::cout << "Test #" << i+1 << ": " << std::hex << instr <<
                        " - ";

                int op = 0b00001;
                int in1 = 0, in2 = 1, wb = 0;
                int af3 = 0, bf3 = 0, lf3 = 0, sf3 = 0, f7 = 0;
                int illegal = 0, ecall = 0, ebreak = 0, mret = 0, sret = 0, wfi = 0;
                int rs1 = rs1(instr), rs2 = rs2(instr), rd = rd(instr);
                int imm = 0;

                switch(opcode(instr)) {
                case 0b0110111: 
                        std::cout << "lui";
                        op = 0b00001;
                        imm = get_u_imm(instr);
                        break;
                case 0b0010111: 
                        std::cout << "auipc";
                        op = 0b00001;
                        in1 = 2;
                        imm = get_u_imm(instr);
                        break;
                case 0b1101111: 
                        std::cout << "jal";
                        op = 0b01001;
                        in1 = 2; wb = 2;
                        imm = get_j_imm(instr);
                        break;
                case 0b1100111: 
                        std::cout << "jalr";
                        op = 0b01001;
                        in1 = 1; wb = 2;
                        if (f3(instr) != 0)
                                illegal = 1;
                        imm = get_i_imm(instr);
                        break;
                case 0b1100011: 
                        std::cout << "branch";
                        op = 0b10000;
                        in1 = 2; in2 = 1;
                        bf3 = f3(instr);
                        if (bf3 == 2 || bf3 == 3)
                                illegal = 1;
                        imm = get_b_imm(instr);
                        break;
                case 0b0000011: 
                        std::cout << "load";
                        op = 0b00101;
                        in1 = 1; wb = 1;
                        lf3 = f3(instr);
                        if (lf3 == 3 || lf3 > 5)
                                illegal = 1;
                        imm = get_i_imm(instr);
                        break;
                case 0b0100011: 
                        std::cout << "store";
                        op = 0b00010;
                        in1 = 1;
                        sf3 = f3(instr);
                        if (sf3 > 2)
                                illegal = 1;
                        imm = get_s_imm(instr);
                        break;
                case 0b0010011: 
                        std::cout << "alui";
                        op = 0b00001;
                        in1 = 1;
                        af3 = f3(instr);
                        imm = get_i_imm(instr);
                        break;
                case 0b0110011: 
                        std::cout << "alur";
                        op = 0b00001;
                        in1 = 1; in2 = 0;
                        af3 = f3(instr);
                        break;
                case 0b0001111: 
                        std::cout << "fence";
                        op = 0b00000;
                        if (f3(instr) != 0)
                                illegal = 1;
                        break;
                case 0b1110011: // Incomplete coverage of illegal cases
                        std::cout << "system";
                        op = 0b00000;
                        if (f3(instr) != 0)
                                illegal = 1;
                        if (rs1(instr) != 0)
                                illegal = 1;
                        if (rd(instr) != 0)
                                illegal = 1;
                        break;
                default:
                        throw std::runtime_error("Bad opcode");
                }

                std::cout << "\n\t";

                set_instr(instr);
                pulse();

                // Control word checks
                if (op(get_ctrl()) != op)
                        std::cout << "op failed: " << op(get_ctrl()) << " " << op
                                << "\n\t";

                if (af3(get_ctrl()) != af3)
                        std::cout << "af3 failed: " << af3(get_ctrl()) << " " << af3
                                << "\n\t";

                if (bf3(get_ctrl()) != bf3)
                        std::cout << "bf3 failed: " << bf3(get_ctrl()) << " " << bf3
                                << "\n\t";

                if (lf3(get_ctrl()) != lf3)
                        std::cout << "lf3 failed: " << lf3(get_ctrl()) << " " << lf3
                                << "\n\t";

                if (sf3(get_ctrl()) != sf3)
                        std::cout << "sf3 failed: " << sf3(get_ctrl()) << " " << sf3
                                << "\n\t";

                if (src1(get_ctrl()) != in1)
                        std::cout << "in1 failed: " << src1(get_ctrl()) << " " << in1
                                << "\n\t";

                if (src2(get_ctrl()) != in2)
                        std::cout << "in2 failed: " << src2(get_ctrl()) << " " << in2
                                << "\n\t";

                // System word checks
                if (illegal(get_system()) != illegal)
                        std::cout << "illegal failed: " << illegal(get_system()) << " " << illegal
                                << "\n\t";

                // Operand checks
                if (get_imm() != imm)
                        std::cout << "imm failed: " << get_imm() << " " << imm
                                << "\n\t";

                if (get_rs1() != rs1)
                        std::cout << "rs1 failed: " << get_rs1() << " " << rs1
                                << "\n\t";

                if (get_rs2() != rs2)
                        std::cout << "rs2 failed: " << get_rs2() << " " << rs2
                                << "\n\t";

                if (get_rd() != rd)
                        std::cout << "rd failed: " << get_rd() << " " << rd
                                << "\n\t";


                std::cout << std::dec << std::endl;
        }

        std::cout << "=== Testing Complete ===" << std::endl;
        
        return;
}

} // namespace sim

int get_i_imm(int i)
{
        int imm = i >> 20;

        return imm;
}

int get_u_imm(int i)
{
        int mask = -1 << 12;
        return i & mask;
}

int get_s_imm(int i)
{
        int sign_sel = 1 << 31;
        int sign = (sign_sel & i) >> (31-12);

        int imm_lo_sel = 31;
        int imm_lo = (i >> 7) & imm_lo_sel;

        int imm_hi_sel = 127 << 5;
        int imm_hi = (i >> (25-5)) & imm_hi_sel;

        int imm = imm_hi | imm_lo | sign;

        return imm;
}

int get_b_imm(int i)
{
        int sign_sel = 1 << 31;
        int sign = (sign_sel & i) >> (31-12);

        int imm10_5_sel = 63 << 25;
        int imm4_1_sel = 15 << 8;
        int imm11_sel = 1 << 7;

        int imm10_5 = (imm10_5_sel & i) >> (25-5);
        int imm4_1 = (imm4_1_sel & i) >> (8-1);
        int imm11 = (imm11_sel & i) << (11-7);

        int imm = sign | imm11 | imm10_5 | imm4_1;

        return imm;
}

int get_j_imm(int i)
{
        int sign_sel = 1 << 31;
        int sign = (sign_sel & i) >> (31 - 20);

        int imm10_1_sel = 1023 << 21;
        int imm11_sel = 1 << 20;
        int imm19_12_sel = 255 << 12;

        int imm10_1 = (imm10_1_sel & i) >> (21-1);
        int imm11 = (imm11_sel & i) >> (20-11);
        int imm19_12 = (imm19_12_sel & i);

        int imm = sign | imm19_12 | imm11 | imm10_1;
        return imm;
}

