#include "hart.hpp"
#include "generator.hpp"
#include "riscv_cosim.hpp"

#include "Vtop_hart.h"
#include "Vtop_commit_ifc__P80.h"
#include "Vtop_rob__Cz5_Dz1_Iz2_CBz3_CCz4.h"

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

#define slice(x, msb, lsb) ((x & ((2 << msb) - 1)) >> lsb)

int opcodes[] = {
        0b01101, // lui
        0b00101, // auipc
//      0b11011, // jal
//      0b11001, // jalr
//      0b11000, // branch
//      0b00000, // load
//      0b01000, // store
        0b00100, // alui
        0b01100, // alur
//      0b00011, // fence 
//      0b11100  // system
};

void read_program(std::string, std::vector<unsigned char>&);
void VlWide_to_rat(VlWide<6> wide, unsigned int arr[]);

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
bool hart::get_commit() { return dut->hart->commit_ifc->commit; }
uint32_t hart::get_result() { return dut->hart->commit_ifc->value; }
uint32_t hart::get_pc() { return dut->hart->rob->pc; }

void hart::print_regfile() {
        std::cout << "Register File" << std::endl; // lol
}

int hart::run_tests(int cycles)
{
        sim::generator instr_gen;
        std::vector<uint8_t> prog;
        sim::rv32ui soft_core;
        std::vector<uint32_t> soft_pcs;
        std::vector<uint32_t> soft_results;
        std::vector<uint32_t> hard_pcs;
        std::vector<uint32_t> hard_results;

        instr_gen.add_field(1, 0, 3);
        instr_gen.add_field(6, 2, opcodes, sizeof(opcodes) / sizeof(int));
        instr_gen.add_field(11, 7, 0, 31);
        instr_gen.add_field(14, 12, 0);
        instr_gen.add_field(19, 15, 0, 31);
        instr_gen.add_field(24, 20, 0, 31);
        instr_gen.add_field(31, 25, 0);

        // Populate program w/ random instrs
        for (int i = 0; i < 4096; i++) {
                prog.push_back(instr_gen.generate());
        }

        // Execute software model
        for (int i = 0; i < cycles; i++) {
                soft_core.eval(prog[soft_core.get_nextpc() & 0xfff]);
                soft_pcs.push_back(soft_core.get_pc());
                soft_results.push_back(soft_core.get_result());
        }

        reset(6);
        set_i_ready(1);

        for (int i = 0; i < 16 * cycles; i++) {
                set_i_data(prog[get_i_addr()]);

                pulse();

                if (get_commit()) {
                        hard_pcs.push_back(get_pc());
                        hard_results.push_back(get_result());
                }

                if (hard_pcs.size() == cycles) {
                        break;
                }
        }

        std::cout << std::hex;

        for (int i = 0; i < hard_pcs.size(); i++) {
                if ((hard_pcs.at(i) == soft_pcs.at(i)) &&
                        (hard_results.at(i) == soft_results.at(i))) {
                        std::cout << "--  " << hard_pcs.at(i) << "\t" <<
                                hard_results.at(i) << std::endl;
                } else {
                        std::cout << ">>  " << hard_pcs.at(i) << "\t" <<
                                hard_results.at(i) << std::endl;
                        std::cout << "    " << soft_pcs.at(i) << "\t" <<
                                soft_results.at(i) << std::endl;
                }
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

void VlWide_to_rat(VlWide<6> wide, unsigned int arr[])
{
        uint8_t hi_bits;
        uint8_t lo_bits;

        uint8_t hi_idx;
        uint8_t hi_offset;

        uint8_t lo_idx;
        uint8_t lo_offset;

        for (uint32_t i = 0; i < 32; i++) {
                hi_idx = (6 * i) + 5;
                hi_offset = hi_idx % 32;
                hi_idx /= 32;

                lo_idx = 6 * i;
                lo_offset = lo_idx % 32;
                lo_idx /= 32;

                if (hi_idx > lo_idx) {
                        hi_bits = slice(wide[hi_idx], hi_offset, 0) << (32 - lo_offset);
                        lo_bits = wide[lo_idx] >> lo_offset;
                } else {
                        hi_bits = 0;
                        lo_bits = slice(wide[lo_idx], hi_offset, lo_offset);
                }

                arr[i] = hi_bits | lo_bits;
        }
}
