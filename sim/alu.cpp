#include <iostream>
#include "alu.hpp"
#include "generator.hpp"

#define src1(x) ((x & (0b11 << 22)) >> 22)
#define src2(x) ((x & (0b1 << 21)) >> 21)
#define af3(x) ((x & (0b111 << 16)) >> 16)
#define bf3(x) ((x & (0b111 << 13)) >> 13)
#define f7(x) ((x & (0b1 << 5)) >> 5)

namespace sim
{

int ops[] = {
        0b10000, // branch
        0b01001, // jump
        0b00101, // load
        0b00010, // store
        0b00001  // alu
};

int bf3s[] = {
        0b000, // beq
        0b001, // bne
        0b100, // blt
        0b101, // bge
        0b110, // bltu
        0b111  // bgeu
};

alu::alu(std::shared_ptr<VerilatedContext> ctx) :
        device(ctx)
{
        dut->stall = 0;
        dut->flush = 0;

        dut->ctrl_i = 0;
        dut->rs1_value = 0;
        dut->rs2_value = 0;
        dut->imm = 0;
        dut->pc = 0;
}

alu::~alu()
{}

void alu::stall(int n)
{
        dut->stall = 1;
        for (int i = 0; i < n; i++) {
                pulse();
        }
        dut->stall = 0;
}

void alu::flush(int n)
{
        dut->flush = 1;
        for (int i = 0; i < n; i++) {
                pulse();
        }
        dut->flush = 0;
}

void alu::set_ctrl(unsigned long long in) { dut->ctrl_i = in; }
void alu::set_rs1val(int in) { dut->rs1_value = in; }
void alu::set_rs2val(int in) { dut->rs2_value = in; }
void alu::set_imm(int in) { dut->imm = in; }
void alu::set_pc(int in) { dut->pc = in; }

int alu::get_result() { return dut->result_o; }
bool alu::get_branch() { return dut->branch_o; }

void alu::run_tests(int cycles)
{
        int ctrl, rs1, rs2, imm, pc, expected, expected_branch;
        int in1, in2;

        std::cout << "=== Begin ALU testing ===" << std::endl;

        sim::generator gen;
                                                
        gen.add_field(23, 22, 0, 2);    // alu_src1
        gen.add_field(21, 21, 0, 1);    // alu_src2
                                        
        gen.add_field(18, 16, 0, 7);    // alu_funct3
        gen.add_field(15, 13, bf3s, 6); // branch_funct3
        
        gen.add_field(5, 5, 0, 1);      // funct7
        
        reset(5);

        for (int i = 0; i < cycles; i++)
        {
                ctrl = gen.generate();
                rs1 = rand() | ((rand() % 2) << 31);
                rs2 = rand() | ((rand() % 2) << 31);
                imm = rand();
                pc = rand() | ((rand() % 2) << 31);
                
                std::cout << "Test #" << i << ": \n\trs1 = " << rs1
                        << "\n\trs2 = " << rs2 << "\n\timm = " << imm
                        << "\n\tpc = " << pc << std::endl;

                switch (src1(ctrl)) {
                case 0: 
                        in1 = 0;
                        std::cout << "\tin1 is zero" << std::endl;
                        break;
                case 1: 
                        in1 = rs1; 
                        std::cout << "\tin1 is rs1" << std::endl;
                        break;
                case 2: 
                        in1 = pc;
                        std::cout << "\tin1 is pc" << std::endl;
                        break;
                default: throw std::runtime_error("Got invalid in1 specifier");
                }

                switch (src2(ctrl)) {
                case 0: 
                        in2 = rs2;
                        std::cout << "\tin2 is rs2" << std::endl;
                        break;
                case 1: 
                        in2 = imm; 
                        std::cout << "\tin2 is imm" << std::endl;
                        break;
                default: throw std::runtime_error("Got invalid in2 specifier");
                }

                std::cout << "\t";

                switch(af3(ctrl)) {
                case 0: 
                        if (f7(ctrl)) {
                                expected = in1 - in2;
                                std::cout << "sub";
                        } else {
                                expected = in1 + in2;
                                std::cout << "add";
                        }
                        break;
                case 1: 
                        expected = in1 << (in2 & 0b11111);
                        std::cout << "sll";
                        break;
                case 2: expected = in1 < in2; std::cout << "slt"; break;
                case 3:
                        expected = (unsigned int)in1 < (unsigned int)in2; 
                        std::cout << "sltu";
                        break;
                case 4: expected = in1 ^ in2; std::cout << "xor"; break;
                case 5:
                        if (f7(ctrl)) {
                                expected = in1 >> (in2 & 0b11111);
                                std::cout << "sra";
                        } else {
                                expected = (unsigned int)in1 >> (in2 & 0b11111);
                                std::cout << "srl";
                        }
                        break;
                case 6: expected = in1 | in2; std::cout << "or"; break;
                case 7: expected = in1 & in2; std::cout << "and"; break;
                default: throw std::runtime_error("Got invalid af3");
                }

                std::cout << std::endl;
                std::cout << "\t";

                switch(bf3(ctrl)) {
                case 0: expected_branch = rs1 == rs2; std::cout << "beq"; break;
                case 1: expected_branch = rs1 != rs2; std::cout << "bne"; break;
                case 4: expected_branch = rs1 < rs2; std::cout << "blt"; break;
                case 5: expected_branch = rs1 >= rs2; std::cout << "bge"; break;
                case 6: 
                        expected_branch = (unsigned int)rs1 < (unsigned int)rs2;
                        std::cout << "bltu";
                        break;
                case 7: 
                        expected_branch = (unsigned int)rs1 >= (unsigned int)rs2; 
                        std::cout << "bgeu";
                        break;
                default: throw std::runtime_error("Got invalid bf3");
                }

                std::cout << std::endl;

                dut->ctrl_i = ctrl;
                dut->rs1_value = rs1;
                dut->rs2_value = rs2;
                dut->imm = imm;
                dut->pc = pc;

                pulse();
                
                if (expected != dut->result_o) {
                        std::cout << "ALU gave " << dut->result_o
                                << "; expected " << expected << std::endl;

                }
                else
                        std::cout << "ALU passed." << std::endl;

                if (expected_branch != dut->branch_o)
                        std::cout << "Branch gave " << dut->branch_o
                                << "; expected " << expected_branch << std::endl;
                else
                        std::cout << "Branch passed." << std::endl;
                
        }
}

} // namespace sim
