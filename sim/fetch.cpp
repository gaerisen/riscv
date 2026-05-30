#include "fetch.hpp"
#include "generator.hpp"
#include <iostream>

#define opcode(x) (x & 0b1111111)
#define rd(x) ((x & (0b11111 << 7)) >> 7)
#define f3(x) ((x & (0b111 << 12)) >> 12)
#define rs1(x) ((x & (0b11111 << 15)) >> 15)
#define rs2(x) ((x & (0b11111 << 20)) >> 20)
#define f7(x) ((x & (0b1111111 << 25)) >> 25)

int opcodes[] = {
        //0b01101, // lui
        //0b00101, // auipc
        0b11011, // jal
        0b11001, // jalr
        0b11000, // branch
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100, // alui
        0b00100 // alui
        //0b01100 // alur
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

unsigned int program[] = {
        0x13,
        0x13,
        0xfe0007e3,
        0x13,
        0x13,
        0x13,
        0x13,
        0xfe0007e3,
        0x13,
        0x13,
        0x13,
        0x13,
        0xfe0007e3,
        0x13,
        0x13,
        0xfe0007e3,
        0x13,
        0x13,
        0xfe0007e3,
        0x13,
        0x13,
        0xfe0007e3,
        0x13,
        0x13,
        0xfe0007e3,
        0x13,
        0x13,
        0xfe0007e3,
        0x13,
        0x13,
        0xfe0007e3,
        0x13
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
void fetch::set_branch_taken(bool in) { dut->branch_taken = in; }
void fetch::set_alu_result(int in) { dut->alu_result = in; }
void fetch::set_system(int in) { dut->system_word = in; }
void fetch::set_mtvec(int in) { dut->mtvec = in; }
void fetch::set_mepc(int in) { dut->mepc = in; }
void fetch::set_pc_dec(int in) { dut->pc_from_dec = in; }
void fetch::set_pc_exe(int in) { dut->pc_from_exe = in; }

void fetch::run_tests(int cycles)
{
        struct sim::generator system_gen;
        struct sim::generator instr_gen;

        bool branch;
        bool branch_taken;
        bool jump;
        bool call;
        bool i_data_ready;
        int system;
        int instr = 0, instr_dec = 0, instr_exe = 0, instr_dly = 0;
        int alu_result;
        int pc_dec = 0, pc_exe = 0, pc_dly = 0;

        // Stolen from decoder.cpp just for fun; should not impact operation
        instr_gen.add_field(1, 0, 3);
        instr_gen.add_field(6, 2, opcodes, 19); // limited set; alui, j's, b's
        instr_gen.add_field(11, 7, 0x10); // hardcode bimm[4]
        instr_gen.add_field(25, 25, 1); //hardcode b/jimm[5]

        system_gen.add_field(5, 0, sys_words, 8);

        std::cout << "=== Begin Fetch Testing ===" << std::endl;

        int miss_done = 0;

        reset(5);

        for (int i = 0; i < cycles; i++) {

                branch = (opcode(instr_exe) == 0x63);
                jump = (opcode(instr_exe) == 0x6f);
                call = (opcode(instr_exe) == 0x67);

                alu_result = branch ? 0 /*(pc_exe + 48)*/ :
                                jump ? (pc_exe + 32) :
                                call ? (0x100) : 
                                0;

                branch_taken = 1;
                
                if (call) miss_done = i + 4;

                i_data_ready = i >= miss_done;

           /*     if (i_data_ready) {
                        instr = instr_gen.generate();
                }*/

                instr = program[i];

                set_pc_dec(pc_dec);
                set_pc_exe(pc_exe);
                set_branch(branch);
                set_branch_taken(branch_taken);
                set_jump(jump | call);
                set_alu_result(alu_result);
                set_i_data_i(instr);
                set_i_data_ready(i_data_ready);

                std::cout << "Test #" << i+1 << ": " << std::hex << instr << " "
                        << i_data_ready << "\n\tb: " << branch << " j: " << jump
                        << " sys: " << system;

                pulse();

                std::cout << "\n\tpc: " << get_pc() << " instr: " << get_instr()
                        << " v: " << get_valid() << "\n" << std::endl;

                instr_exe = instr_dec;
                instr_dec = instr_dly;
                instr_dly = instr;

                pc_exe = pc_dec;
                pc_dec = pc_dly;
                pc_dly = get_pc();
        }

        std::cout << "=== Testing Complete ===" << std::endl;
        
        return;
}

} // namespace sim
