#include "hart.hpp"
#include "Vtop_hart.h"
#include "generator.hpp"
#include <iomanip>
#include <iostream>
#include <fstream>
#include <vector>

#define byte(x) (x & 0b11111111)
#define fvlsb(x) (x & 0b11111)
#define opcode(x) (x & 0b1111111)
#define rd(x) ((x & (0b11111 << 7)) >> 7)
#define f3(x) ((x & (0b111 << 12)) >> 12)
#define rs1(x) ((x & (0b11111 << 15)) >> 15)
#define rs2(x) ((x & (0b11111 << 20)) >> 20)
#define f7(x) ((x & (0b1111111 << 25)) >> 25)

int opcodes[] = {
        0b01101, // lui
        0b00101, // auipc
        0b11011, // jal
        0b11001, // jalr
        0b11000, // branch
//      0b00000, // load
//      0b01000, // store
        0b00100, // alui
        0b01100, // alur
//      0b00011, // fence 
//      0b11100  // system
};

void read_program(std::string, std::vector<unsigned char>&);

namespace sim
{

hart::hart(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

hart::~hart()
{}

void hart::set_i_ready(int in) { dut->i_data_ready = in; }
void hart::set_i_data(int in) { dut->i_data = in; }

int hart::get_i_addr() { return dut->i_addr; }

void hart::print_regfile() {
        std::cout << "Register File" << std::endl;
        int startln;

        for (int i = 0; i < 8; i++) {
                startln = i * 4;
                for (int j = 0; j < 4; j++) {
                        std::cout << "\tx" << std::dec <<  startln + j << " =\t"
                                << std::hex << "0x" << std::setw(8)
                                << std::setfill('0')
                                << dut->hart->irf[startln + j];
                }
                std::cout << "\n";
        }

        std::cout << std::endl;
}

int hart::run_tests(int cycles)
{
        struct sim::generator instr_gen;

        instr_gen.add_field(1, 0, 3);
        instr_gen.add_field(6, 2, opcodes, 11); 

        // Masked random to make immediates word-aligned for jumps
        int idx = instr_gen.add_field(31, 7, RAND_MASK);

        //                                    jal(r) imm[1]    branch imm[1]
        //                                            v            v
        instr_gen.fields.at(idx).set_mask(0b1111111111001111111111101);
        //                                             ^
        //                                         jalr imm[0]

        // Hardware model execution
        reset(6);

        set_i_ready(1);

        std::vector<unsigned char> prog;

        read_program("prog.bin", prog);
        
        // Pad end of memory with some NOPs
        for (int i = 0; i < 32; i++) {
                prog.push_back(0x13);
                prog.push_back(0x00);
                prog.push_back(0x00);
                prog.push_back(0x00);
        }


        unsigned int last_block;
        unsigned int instr;
        unsigned int addr = 0;

        int miss_done = 0;

        int status = 1;

        for (int i = 0; i < cycles; i++) {
                last_block = addr >> 8;

                addr = get_i_addr();

                // Construct instruction from bytes
                instr = prog.at(addr + 3);
                instr <<= 8;
                instr |= prog.at(addr + 2);
                instr <<= 8;
                instr |= prog.at(addr + 1);
                instr <<= 8;
                instr |= prog.at(addr + 0);

                // Simulate cache misses
                if (last_block != addr >> 8)
                        miss_done = i + 10;

                set_i_ready(i > miss_done);

                set_i_data(instr);

                pulse();

                // Workaround for checking exit status without memory iface
                if (dut->hart->ctrl_mem & (1 << 29)) {
                        status = !(dut->hart->irf[3] == 1);
                        break;
                }
        }

        return status;
}

} // namespace sim

void read_program(std::string filename, std::vector<unsigned char>& vec)
{
        std::ifstream ifs(filename, std::ios::in | std::ios::binary);

        while (ifs) {
                vec.push_back(ifs.get());
        }
}
