#include <iostream>
#include "alu.hpp"

// Control word manipulation macros

#define set_op(x, op) (x = ((x & ~(127 << 29)) | (op << 29)))
#define set_f3(x, f3) (x = ((x & ~(7 << 26)) | (f3 << 26)))
#define set_f7(x, f7) (x = ((x & ~(127 << 19)) | (f7 << 19)))
#define set_src1(x, src1) (x = ((x & ~(3 << 17)) | (src1 << 17)))
#define set_src2(x, src2) (x = ((x & ~(1 << 16)) | (src2 << 16)))
#define set_branch(x, branch) (x = ((x & ~(1 << 15)) | (branch << 15)))
#define set_bf3(x, bf3) (x = ((x & ~(7 << 12)) | (bf3 << 12)))
#define set_jump(x, jump) (x = ((x & ~(1 << 11)) | (jump << 11)))
#define set_load(x, load) (x = ((x & ~(1 << 10)) | (load << 10)))
#define set_lf3(x, lf3) (x = ((x & ~(7 << 7)) | (lf3 << 7)))
#define set_store(x, store) (x = ((x & ~(1 << 6)) | (store << 6)))
#define set_sf3(x, sf3) (x = ((x & ~(7 << 3)) | (sf3 << 3)))
#define set_wb(x, wb) (x = ((x & ~(1 << 2)) | (wb << 2)))
#define set_wb_src(x, wb_src) (x = ((x & ~(3 << 0)) | (wb_src << 0)))

namespace sim
{

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

void alu::run_tests()
{
        std::cout << "=== Begin ALU testing ===" << std::endl;
        
        int rs1 = rand();
        int rs2 = rand();
        int imm = rand();
        int pc = rand();

        set_rs1val(rs1);
        set_rs2val(rs2);
        set_imm(imm);
        set_pc(pc);

        // Setup a simple register add
        unsigned long long ctrl = 0;
        set_f3(ctrl, 0b000);
        set_f7(ctrl, 0b0000000);
        set_src1(ctrl, 0); // rs1
        set_src2(ctrl, 0); // rs2

        set_ctrl(ctrl);
        pulse();
        int result = get_result();
        std::cout << "rs1 + rs2: ";

        if (result != rs1 + rs2) {
                std::cout << "FAILED: Got " << result << ", expected "
                        << rs1 + rs2;
        }
        std::cout << std::endl;

        set_src2(ctrl, 1);
        set_ctrl(ctrl);
        pulse();
        result = get_result();
        std::cout << "rs1 + imm: ";
        if (result != rs1 + imm) {
                std::cout << "FAILED: Got " << result << ", expected "
                        << rs1 + imm;
        }
        std::cout << std::endl;

        set_src1(ctrl, 1);
        set_ctrl(ctrl);
        pulse();
        result = get_result();
        std::cout << "pc + imm: ";

        if (result != pc + imm) {
                std::cout << "FAILED: Got " << result << ", expected "
                        << pc + imm;
        }
        std::cout << std::endl;
}

} // namespace sim
