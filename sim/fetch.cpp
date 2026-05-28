#include "fetch.hpp"
#include "generator.hpp"
#include <iostream>

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

int sys_words[] = {
        0,
        0,
        0,
        0,
        0b100000,
        0b010000,
        0b001000,
        0b000100
};

namespace sim
{

fetch::fetch(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

fetch::~fetch()
{}

int fetch::get_pc() { return dut->pc_o; }
int fetch::get_instr() { return dut->instr_o; }
bool fetch::get_valid() { return dut->valid_o; }

void fetch::set_i_data_ready(int in) { dut->i_data_ready = in; }
void fetch::set_i_data_i(int in) { dut->i_data_i = in; }
void fetch::set_jump(bool in) { dut->jump = in; }
void fetch::set_branch(bool in) { dut->branch = in; }
void fetch::set_alu_result(int in) { dut->alu_result = in; }
void fetch::set_system(int in) { dut->system_word = in; }
void fetch::set_mtvec(int in) { dut->mtvec = in; }
void fetch::set_mepc(int in) { dut->mepc = in; }

void fetch::run_tests(int cycles)
{
        struct sim::generator system_gen;
        struct sim::generator instr_gen;

        bool branch;
        bool jump;
        bool i_data_ready;
        int system;
        int instr;

        // Hardcode vectors for now, for easier debugging
        set_alu_result(0x100);
        set_mtvec(0x200);
        set_mepc(0x300);

        // Stolen from decoder.cpp just for fun; should not impact operation
        instr_gen.add_field(1, 0, 3);
        instr_gen.add_field(6, 2, opcodes, 11);
        instr_gen.add_field(11, 7, 0, 31);
        instr_gen.add_field(14, 12, 0, 7);
        instr_gen.add_field(19, 15, 0, 31);
        instr_gen.add_field(24, 20, 0, 31);
        instr_gen.add_field(31, 25, 0, 127);

        system_gen.add_field(5, 0, sys_words, 8);

        std::cout << "=== Begin Fetch Testing ===" << std::endl;

        int miss_done = 0;

        reset(5);

        for (int i = 0; i < cycles; i++) {
                system = system_gen.generate();

                jump = (rand() % 8) == 0;
                branch = !jump & ((rand() % 8) == 0);
                
                // Simulate random cache misses
                if (i > miss_done && (rand() % 4) == 0) {
                        miss_done = i + 4;
                }

                i_data_ready = miss_done >= i;

                if (i_data_ready) {
                        instr = instr_gen.generate();
                }

                set_i_data_i(instr);
                set_i_data_ready(i_data_ready);
                set_branch(branch);
                set_jump(jump);
                set_system(system);

                std::cout << "Test #" << i+1 << ": " << std::hex << instr << " "
                        << i_data_ready << "\n\tb: " << branch << " j: " << jump
                        << " sys: " << system;

                pulse();

                std::cout << "\n\tpc: " << get_pc() << " instr: " << get_instr()
                        << " v: " << get_valid() << "\n" << std::endl;
        }

        std::cout << "=== Testing Complete ===" << std::endl;
        
        return;
}

} // namespace sim
