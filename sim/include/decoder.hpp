#ifndef DECODER_HPP
#define DECODER_HPP

#include "device.hpp"

namespace sim
{

struct decoder : public device {

        decoder(std::shared_ptr<VerilatedContext> ctx);
        ~decoder();

        void flush(int);
        void stall(int);

        void set_instr(unsigned int i) { dut->instr_i = i; }

        int get_rs1() { return dut->rs1_o; }
        int get_rs2() { return dut->rs2_o; }
        int get_rd() { return dut->rd_o; }
        int get_imm() { return dut->imm_o; }
        int get_ctrl() { return dut->ctrl_o; }
        int get_system() { return dut->system_o; }

        void run_tests(int);
};

} // namespace sim

int get_i_imm(int);
int get_s_imm(int);
int get_b_imm(int);
int get_u_imm(int);
int get_j_imm(int);

#endif // DECODER_HPP
