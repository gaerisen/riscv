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

int auimm_ops[] = { 0x37, 0x17 };

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
        std::vector<uint8_t> prog;
        sim::rv32ui soft_core;
        std::vector<uint32_t> soft_pcs;
        std::vector<uint32_t> soft_results;
        std::vector<uint32_t> hard_pcs;
        std::vector<uint32_t> hard_results;
        uint32_t instr;
        uint32_t addr;

        sim::generator alui_gen;
        sim::generator alur_gen;
        sim::generator auimm_gen;
        sim::generator branch_gen;
        sim::generator jal_gen;
        sim::generator jalr_gen;

        alui_gen.add_field(6, 0, 0x13);
        alui_gen.add_field(11, 7, 0, 31);
        alui_gen.add_field(14, 12, 0, 7);
        alui_gen.add_field(19, 15, 0, 31);
        alui_gen.add_field(31, 20, 0, 31);

        alur_gen.add_field(6, 0, 0x33);
        alur_gen.add_field(11, 7, 0, 31);
        alur_gen.add_field(14, 12, 0, 7);
        alur_gen.add_field(19, 15, 0, 31);
        alur_gen.add_field(24, 20, 0, 31);
        alur_gen.add_field(31, 25, 0);

        auimm_gen.add_field(6, 0, auimm_ops, 2);
        auimm_gen.add_field(11, 7, 0, 31);
        auimm_gen.add_field(31, 12, 0, 0xfffff);

        // Populate program w/ random instrs
        for (int i = 0; i < 1024; i++) {
                instr = alui_gen.generate();
                prog.push_back(byte(instr));
                instr >>= 8;
                prog.push_back(byte(instr));
                instr >>= 8;
                prog.push_back(byte(instr));
                instr >>= 8;
                prog.push_back(byte(instr));
        }

        // Dump program for observation
        std::ofstream ofs("random.bin", std::ios::out | std::ios::binary);
        ofs.write((char *)prog.data(), prog.size());

        // Execute software model
        for (int i = 0; i < cycles; i++) {
                addr = soft_core.get_nextpc() & 0xfff;
                instr = prog[addr];
                instr |= prog[addr + 1] << 8;
                instr |= prog[addr + 2] << 16;
                instr |= prog[addr + 3] << 24;
        
                soft_core.eval(instr);
                soft_pcs.push_back(soft_core.get_pc());
                soft_results.push_back(soft_core.get_result());
        }

        reset(6);
        set_i_ready(1);

        for (int i = 0; i < 16 * cycles; i++) {
                addr = get_i_addr() & 0xfff;
                instr = prog[addr];
                instr |= prog[addr + 1] << 8;
                instr |= prog[addr + 2] << 16;
                instr |= prog[addr + 3] << 24;

                set_i_data(instr);

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
