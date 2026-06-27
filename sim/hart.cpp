#include "hart.hpp"
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
        std::cout << "Register File" << std::endl; // lol
}

int hart::run_tests(int cycles)
{
        std::ifstream progfs("progs.txt");
        std::vector<unsigned char> prog;
        std::string filename;

        int count = 1;

        while (true) {
                prog.clear();

                std::getline(progfs, filename);
                if (!progfs) break;

                std::cout << "[" << count << "] " << std::setw(30) << std::left
                        << filename;
                count++;

                read_program(filename, prog);
                
                // Pad end of memory with some NOPs
                for (int i = 0; i < 32; i++) {
                        prog.push_back(0x13);
                        prog.push_back(0x00);
                        prog.push_back(0x00);
                        prog.push_back(0x00);
                }

                unsigned int last_block = 0;
                unsigned int instr;
                unsigned int addr = 0;

                int miss_done = 0;
                int status = 1;

                reset(6);

                for (int i = 0; true; i++) {
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
                                miss_done = i + 16;

                        set_i_ready(i >= miss_done);
//                        set_i_ready(1);

                        set_i_data(instr);

                        pulse();

                        // Workaround for checking exit status without memory iface
                        if (dut->d_valid) {
                                status = !(dut->d_data_o == 1);
                                break;
                        }
                }

                if (status) std::cout << "Failed";
                std::cout << std::endl;
        }
        
        return 0;
}

} // namespace sim

void read_program(std::string filename, std::vector<unsigned char>& vec)
{
        std::ifstream ifs(filename, std::ios::in | std::ios::binary);

        while (ifs) {
                vec.push_back(ifs.get());
        }
}
