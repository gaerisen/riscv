#include "fetch.hpp"
#include "generator.hpp"
#include <iostream>

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
        0b00000, // load
        0b01000, // store
        0b00100, // alui
        0b01100, // alur
        0b00011, // fence 
        0b11100  // system
};

int get_i_imm(int i);
int get_b_imm(int i);
int get_j_imm(int i);

namespace sim
{

fetch::fetch(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

fetch::~fetch()
{}

int fetch::get_i_addr() { return dut->i_addr; }
int fetch::get_pc() { return dut->pc_o; }
int fetch::get_instr() { return dut->instr_o; }
bool fetch::get_valid() { return dut->valid_o; }
bool fetch::get_flush() { return dut->flush_o; }

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

int fetch::run_tests(int cycles)
{
        struct sim::generator instr_gen;

        std::vector<unsigned int> pcs_ideal;
        std::vector<unsigned int> pcs_sim;

        int imem[256];
        bool branches[32];

        bool branch;
        bool jal;
        bool jalr;
        bool i_data_ready;
        int system;
        int alu_result;

        // PC and instr buffers to simulate decode and exe flip-flops
        int pc = 0, pc_dec = 0, pc_exe = 0, pc_dly = 0;
        int instr = 0, instr_dec = 0, instr_exe = 0, instr_dly = 0;
        bool branch_taken, branch_taken_dly, branch_taken_dec, branch_taken_exe;

        // Stolen from decoder.cpp just for fun; should not impact operation
        instr_gen.add_field(1, 0, 3);
        instr_gen.add_field(6, 2, opcodes, 11); 

        // Masked random to make immediates word-aligned
        int idx = instr_gen.add_field(31, 7, RAND_MASK);

        //                                    jal(r) imm[1]    branch imm[1]
        //                                            v            v
        instr_gen.fields.at(idx).set_mask(0b1111111111001111111111101);
        //                                             ^
        //                                         jalr imm[0]

        std::cout << "=== Begin Fetch Testing ===" << std::endl;

        int miss_done = 0;

        // Program generation
        for (int i = 0; i < 256; i++) {
                imem[i] = instr_gen.generate();
                std::cout << std::hex << "0x" << byte(i) << ":\t" << imem[i]
                        << std::endl;
        }
        for (int i = 0; i < 32; i++) {
                branches[i] = rand() % 2;
        }

        // Hardware model execution
        reset(6);
        dut->eval();

        set_i_data_ready(1);

        instr = imem[0];
        set_i_data_i(instr);

        int valid_ctr = 0;

        for (int i = 0; i < cycles; i++) {
                pulse();

                if (get_flush()) {
                        for (int j = 0; j < valid_ctr; j++)
                                pcs_sim.pop_back();

                        instr_exe = 0x13;
                        instr_dec = 0x13;
                }

                set_pc_exe(pc_exe);
                set_pc_dec(pc_dec);

                jalr = opcode(instr_exe) == 0x67;
                branch = opcode(instr_exe) == 0x63;
                
                alu_result =    jalr ? 0x100 + get_i_imm(instr_exe) :
                                branch ? pc_exe + get_b_imm(instr_exe) : 0;

                set_jump(jalr);
                set_branch(branch);
                set_branch_taken(branch & branches[fvlsb(pc_exe>>2)]);
                set_alu_result(alu_result);

                pc = get_pc();
                pc_exe = pc_dec;
                pc_dec = pc;

                if (get_valid()) {
                        valid_ctr = (valid_ctr < 2) ? valid_ctr + 1 : 2;
                        pcs_sim.push_back(pc);
                } else {
                        valid_ctr = (valid_ctr > 0) ? valid_ctr - 1 : 0;
                }

                instr_exe = instr_dec;
                instr_dec = get_instr();

                dut->eval();

                instr = imem[byte(get_i_addr()>>2)];
                set_i_data_i(instr);
        }

        // Software model execution
        pc = 0;
        pcs_ideal.push_back(pc);

        std::cout << std::hex;

        for (int i = 0; i < pcs_sim.size(); i++) {
                instr = imem[byte(pc>>2)];

                std::cout << pc << " (" << byte(pc>>2) << ") gives " << instr;

                switch (opcode(instr)) {
                case 0x63:
                        if (branches[fvlsb(pc>>2)]) {
                                pc += get_b_imm(instr);
                                std::cout << " (branch taken to " << pc << ")";
                        } else {
                                pc += 4;
                                std::cout << " (branch not taken)";
                        }
                        break;
                case 0x6f:
                        pc += get_j_imm(instr);
                        std::cout << " (jal to " << pc << ")";
                        break;
                case 0x67:
                        pc = 0x100 + get_i_imm(instr);
                        std::cout << " (jalr to " << pc << ")";
                        break;
                default:
                        pc += 4;
                }
                
                std::cout << std::endl;

                pcs_ideal.push_back(pc);
        }

        int num = (pcs_ideal.size() < pcs_sim.size()) ? pcs_ideal.size()
                        : pcs_sim.size();

        num -= 2;

        int num_errors = 0;

        for (int i = 0; i < num; i++) {
                if (pcs_sim.at(i) != pcs_ideal.at(i)) {
                        std::cout << ">>  ";
                } else {
                        std::cout << "    ";
                }
                std::cout << "[" << pcs_sim.at(i) << ",\t" << pcs_ideal.at(i)
                        << "]" << std::endl;

                if (pcs_ideal.at(i) != pcs_sim.at(i)) num_errors++;
        }

        std::cout << "=== Testing Complete ===" << std::endl;
        
        return num_errors;
}

} // namespace sim

int get_i_imm(int i)
{
        int imm = i >> 20;

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
