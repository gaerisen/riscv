#include <verilated.h>
#include <iostream>
#include <iomanip>
#include <cstdlib>
#include <cstdint>
#include <ctime>

#include "Vdecoder.h"

typedef struct {
        int rs1;
        int rs2;
        int rd;
        int opcode;
        int funct3;
        int funct7;
        int imm;
} instr;

void generate_instrs(instr *is);
void encode_instrs(instr *is, uint32_t *words);

int main(int argc, char *argv[])
{
        VerilatedContext* const ctx = new VerilatedContext;

        ctx->commandArgs(argc, argv);

        Vdecoder* top = new Vdecoder{ctx};

        srand(time(0));
        
        instr is[578];

        generate_instrs(is);

        uint32_t words[578];

        for (int i = 0; i < 578; i++) {
                words[i] = 0;
        }

        encode_instrs(is, words);

        top->clk = 0;
        top->rst = 0;
        top->flush = 0;
        top->stall = 0;

        for (int n = 0; n < (578 * 2); n++) {
                int i = n / 2;

                ctx->timeInc(1);
                
                top->clk = !top->clk;

                top->eval();

                if (top->clk) {
                        top->instr_i = words[i+1];

                        std::cout << "0x" << std::setw(8) << std::setfill('0')
                                << std::hex << words[i] << ' ';

                        std::cout << "Should be ";

                        switch(is[i].opcode) {
                        case 0x37:
                                std::cout << "LUI ";
                                break;
                        case 0x17:
                                std::cout << "AUIPC ";
                                break;
                        case 0x6f:
                                std::cout << "JAL ";
                                break;
                        case 0x67:
                                std::cout << "JALR ";
                                break;
                        case 0x63:
                                std::cout << "BRANCH ";
                                break;
                        case 0x03:
                                std::cout << "LOAD ";
                                break;
                        case 0x23:
                                std::cout << "STORE ";
                                break;
                        case 0x13:
                                std::cout << "ALUI ";
                                break;
                        case 0x33:
                                std::cout << "ALUR ";
                                break;
                        default:
                                std::cout << "OTHER ";
                                break;
                        }

                        std::cout << "rs1=" << is[i].rs1;
                        std::cout << " rs2=" << is[i].rs2;
                        std::cout << " rd=" << is[i].rd;
                        std::cout << " imm=" << is[i].imm;
                        std::cout << std::endl;

                        std::cout << "                  is ";

                        switch(top->opcode_o) {
                        case 0x37:
                                std::cout << "LUI ";
                                break;
                        case 0x17:
                                std::cout << "AUIPC ";
                                break;
                        case 0x6f:
                                std::cout << "JAL ";
                                break;
                        case 0x67:
                                std::cout << "JALR ";
                                break;
                        case 0x63:
                                std::cout << "BRANCH ";
                                break;
                        case 0x03:
                                std::cout << "LOAD ";
                                break;
                        case 0x23:
                                std::cout << "STORE ";
                                break;
                        case 0x13:
                                std::cout << "ALUI ";
                                break;
                        case 0x33:
                                std::cout << "ALUR ";
                                break;
                        default:
                                std::cout << "OTHER ";
                                break;
                        }

                        std::cout << "rs1=" << (int)(top->rs1_o);
                        std::cout << " rs2=" << (int)(top->rs2_o);
                        std::cout << " rd=" << (int)(top->rd_o);
                        std::cout << " imm=" << (int)(top->imm_o);
                        std::cout << "\n" << std::endl;

                }
        }

        top->final();
        
        delete top;

        return 0;
}

void generate_instrs(instr *is)
{
        uint32_t i;

        for (i = 0; i < 32; i++) { // LUI
                is[i].opcode = 0b0110111;
                is[i].rs1 = 0;
                is[i].rs2 = 0;
                is[i].funct3 = 0;
                is[i].funct7 = 0;
                is[i].rd = rand() % 32;
                is[i].imm = rand() << 12;
        }
        for (; i < 64; i++) { // AUIPC
                is[i].opcode = 0b0010111;
                is[i].rs1 = 0;
                is[i].rs2 = 0;
                is[i].funct3 = 0;
                is[i].funct7 = 0;
                is[i].rd = rand() % 32;
                is[i].imm = rand() << 12;
        }
        for (; i < 128; i++) { // JAL
                is[i].opcode = 0b1101111;
                is[i].rs1 = 0;
                is[i].rs2 = 0;
                is[i].funct3 = 0;
                is[i].funct7 = 0;
                is[i].rd = rand() % 32;
                is[i].imm = (rand() % (1 << 20)) << 1;
        }
        for (; i < 192; i++) { // JALR
                is[i].opcode = 0b1101111;
                is[i].rs1 = rand() % 32;
                is[i].rs2 = 0;
                is[i].funct3 = 0;
                is[i].funct7 = 0;
                is[i].rd = rand() % 32;
                is[i].imm = rand() % (1 << 12);
        }
        for (; i < 256; i++) { // BRANCH
                is[i].opcode = 0b1100011;
                is[i].rs1 = rand() % 32;
                is[i].rs2 = rand() % 32;
                is[i].funct3 = rand() % 8;
                is[i].funct7 = 0;
                is[i].rd = 0;
                is[i].imm = (rand() % (1 << 12)) << 1;
        }
        for (; i < 320; i++) { // L
                is[i].opcode = 0b0000011;
                is[i].rs1 = rand() % 32;
                is[i].rs2 = 0;
                is[i].funct3 = rand() % 3;
                is[i].funct7 = 0;
                is[i].rd = rand() % 32;
                is[i].imm = rand() % (1 << 12);
        }
        for (; i < 384; i++) { // LU
                is[i].opcode = 0b0000011;
                is[i].rs1 = rand() % 32;
                is[i].rs2 = 0;
                is[i].funct3 = (rand() % 2) + 4;
                is[i].funct7 = 0;
                is[i].rd = rand() % 32;
                is[i].imm = rand() % (1 << 12);
        }
        for (; i < 448; i++) { // STORE
                is[i].opcode = 0b0100011;
                is[i].rs1 = rand() % 32;
                is[i].rs2 = rand() % 32;
                is[i].funct3 = rand() % 3;
                is[i].funct7 = 0;
                is[i].rd = 0;
                is[i].imm = rand() % (1 << 12);
        }
        for (; i < 512; i++) { // ALUI
                is[i].opcode = 0b0010011;
                is[i].rs1 = rand() % 32;
                is[i].rs2 = 0;
                is[i].funct3 = rand() % 8;
                is[i].funct7 = 0;
                is[i].rd = rand() % 32;
                is[i].imm = rand() % (1 << 12);
        }
        for (; i < 576; i++) { // ALUR
                is[i].opcode = 0b0110011;
                is[i].rs1 = rand() % 32;
                is[i].rs2 = rand() % 32;
                is[i].funct3 = rand() % 8;
                is[i].funct7 = 0;
                is[i].rd = rand() % 32;
                is[i].imm = 0;
        }

        is[576].opcode = 0b0001111; // FENCE
        is[576].rs1 = 0;
        is[576].rs2 = 0;
        is[576].funct3 = 0;
        is[576].funct7 = 0;
        is[576].rd = 0;
        is[576].imm = 0;

        is[577].opcode = 0b1110011; // SYSTEM
        is[577].rs1 = 0;
        is[577].rs2 = 0;
        is[577].funct3 = 0;
        is[577].funct7 = 0;
        is[577].rd = 0;
        is[577].imm = 0;

        return;
}

void encode_instrs(instr *is, uint32_t *words)
{
        uint32_t i;

        for (i = 0; i < 32; i++) { // LUI
                words[i] = (is[i].imm << 12) | 
                        (is[i].rd << 7) |
                        is[i].opcode;
        }
        for (; i < 64; i++) { // AUIPC
                words[i] = (is[i].imm << 12) | 
                        (is[i].rd << 7) |
                        is[i].opcode;
        }
        for (; i < 128; i++) { // JAL
                int imm20 = (is[i].imm & (1 << 20)) << 11;
                int imm10_1 = (is[i].imm & (0b1111111111 << 1)) << 20;
                int imm11 = (is[i].imm & (1 << 11)) << 9;
                int imm19_12 = (is[i].imm & (0b11111111 << 12));

                words[i] = imm20 | imm10_1 | imm11 | imm19_12 |
                        (is[i].rd << 7) |
                        (is[i].funct3 << 12) | 
                        is[i].opcode;
        }
        for (; i < 192; i++) { // JALR
                words[i] = (is[i].imm << 20) |
                        (is[i].rs1 << 15) |
                        (is[i].rd << 7) |
                        is[i].opcode;
        }
        for (; i < 256; i++) { // BRANCH
                int imm12 = (is[i].imm & (1 << 12)) << 19;
                int imm11 = (is[i].imm & (1 << 11)) >> 3;
                int imm10_5 = (is[i].imm & (0b111111 << 5)) << 20;
                int imm4_1 = (is[i].imm & (0b1111 << 1)) << 8;

                words[i] = imm12 | imm11 | imm10_5 | imm4_1 |
                        (is[i].rs2 << 20) |
                        (is[i].rs1 << 15) |
                        (is[i].funct3 << 12) |
                        is[i].opcode;
        }
        for (; i < 320; i++) { // L
                words[i] = (is[i].imm << 20) |
                        (is[i].rs1 << 15) |
                        (is[i].funct3 << 12) |
                        (is[i].rd << 7) |
                        is[i].opcode;
        }
        for (; i < 384; i++) { // LU
                words[i] = (is[i].imm << 20) |
                        (is[i].rs1 << 15) |
                        (is[i].funct3 << 12) |
                        (is[i].rd << 7) |
                        is[i].opcode;
        }
        for (; i < 448; i++) { // STORE
                int imm11_5 = (is[i].imm & (0b1111111 << 5)) << 20;
                int imm4_0 = (is[i].imm & 0b1111) << 7;

                words[i] = imm11_5 | imm4_0 |
                        (is[i].rs2 << 20) |
                        (is[i].rs1 << 15) |
                        (is[i].funct3 << 12) |
                        is[i].opcode;
        }
        for (; i < 512; i++) { // ALUI
                words[i] = (is[i].imm << 20) |
                        (is[i].rs1 << 15) |
                        (is[i].funct3 << 12) |
                        (is[i].rd << 7) |
                        is[i].opcode;
        }
        for (; i < 576; i++) { // ALUR
                words[i] = (is[i].rs2 << 20) |
                        (is[i].rs1 << 15) |
                        (is[i].funct3 << 12) |
                        (is[i].rd << 7) |
                        is[i].opcode;
        }

        words[576] = is[576].opcode; // FENCE
        words[577] = is[577].opcode; // SYSTEM

        return;
}
