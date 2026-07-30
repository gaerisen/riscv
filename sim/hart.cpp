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

#define GEN_ARITH rand() % 3
#define GEN_BRANCH rand() % 4
#define GEN_JAL rand() % 5
#define GEN_REG rand() % 6
#define GEN_ALL rand() % 8

int auimm_ops[] = { 0x37, 0x17 };
int b_f3s[] = { 0, 1, 4, 5, 6, 7 };

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
        std::vector<uint8_t> imem;
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
        sim::generator load_gen;
        sim::generator store_gen;

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

        branch_gen.add_field(6, 0, 0x63);
        branch_gen.fields.at(branch_gen.add_field(11, 7, RAND_MASK)).set_mask(0x1c);
        branch_gen.add_field(14, 12, b_f3s, (sizeof(b_f3s) / sizeof(int)));
        branch_gen.add_field(19, 15, 0, 31);
        branch_gen.add_field(24, 20, 0, 31);
        branch_gen.add_field(31, 25, 0xfff);

        jal_gen.add_field(6, 0, 0x6f);
        jal_gen.add_field(11, 7, 0, 31);
        jal_gen.add_field(14, 12, 0);
        jal_gen.add_field(19, 15, 0);
        jal_gen.add_field(21, 20, 0);
        jal_gen.add_field(24, 22, 0, 7);
        jal_gen.add_field(31, 25, 0xfff);

        jalr_gen.add_field(6, 0, 0x67);
        jalr_gen.add_field(11, 7, 0, 31);
        jalr_gen.add_field(14, 12, 0);
        jalr_gen.add_field(19, 15, 0, 31);
        jalr_gen.add_field(24, 20, 0, 31);
        jalr_gen.add_field(31, 25, 0xfff);

        load_gen.add_field(6, 0, 0x03);
        load_gen.add_field(11, 7, 0, 31);
        load_gen.add_field(14, 12, 0, 2); // TODO: Add unsigned f3s
        load_gen.add_field(19, 15, 0, 31);
        load_gen.add_field(31, 20, 0, 31);

        store_gen.add_field(6, 0, 0x23);
        store_gen.add_field(11, 7, 0, 31);
        store_gen.add_field(14, 12, 0, 2); // TODO: Add unsigned f3s
        store_gen.add_field(19, 15, 0, 31);
        store_gen.add_field(24, 20, 0, 31);
        store_gen.add_field(31, 25, 0, 0);


        sim::generator *generators[8] = {
                &alui_gen,
                &alur_gen,
                &auimm_gen,
                &branch_gen,
                &jal_gen,
                &jalr_gen,
                &load_gen,
                &store_gen
        };

        // Populate imem w/ random instrs
        for (int i = 0; i < 1024; i++) {
                instr = generators[GEN_ALL]->generate();
                imem.push_back(byte(instr));
                instr >>= 8;
                imem.push_back(byte(instr));
                instr >>= 8;
                imem.push_back(byte(instr));
                instr >>= 8;
                imem.push_back(byte(instr));
        }

        // Dump program for observation
        std::ofstream ofs("random.bin", std::ios::out | std::ios::binary);
        ofs.write((char *)imem.data(), imem.size());

        // Execute software model
        for (int i = 0; i < cycles; i++) {
                addr = soft_core.get_nextpc() & 0xfff;
                instr = imem[addr];
                instr |= imem[addr + 1] << 8;
                instr |= imem[addr + 2] << 16;
                instr |= imem[addr + 3] << 24;

                soft_core.eval(instr);
                soft_pcs.push_back(soft_core.get_pc());
                soft_results.push_back(soft_core.get_result());

                if ((instr & 0xfffff07f) == 0x6f) break;
        }

        // Execute hardware model
        reset(6);
        set_i_ready(1);

        uint32_t stop_pc;

        for (int i = 0; i < 16 * cycles; i++) {
                addr = get_i_addr() & 0xfff;
                instr = imem[addr];
                instr |= imem[addr + 1] << 8;
                instr |= imem[addr + 2] << 16;
                instr |= imem[addr + 3] << 24;

                if ((instr & 0xfffff07f) == 0x6f) stop_pc = get_i_addr();

                set_i_data(instr);

                pulse();

                if (get_commit()) {
                        hard_pcs.push_back(get_pc());
                        hard_results.push_back(get_result());
                        if (get_pc() == stop_pc) break;
                }

                if (hard_pcs.size() == cycles) break;
        }

        // Dump any mismatched results
        std::cout << std::hex;

        int count = 0;

        for (int i = 0; i < hard_pcs.size(); i++) {
                if ((hard_pcs.at(i) != soft_pcs.at(i)) ||
                        (hard_results.at(i) != soft_results.at(i))) {
                        std::cout << ">>  " << hard_pcs.at(i) << "\t" <<
                                hard_results.at(i) << std::endl;
                        std::cout << "    " << soft_pcs.at(i) << "\t" <<
                                soft_results.at(i) << std::endl;
                        count++;
                }
        }
        
        return count;
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
