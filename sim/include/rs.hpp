#ifndef RS_HPP
#define RS_HPP

#include "device.hpp"

namespace sim
{

struct rs : public device {
        rs(std::shared_ptr<VerilatedContext> ctx);
        ~rs();

        void set_issue(bool val) { dut->issue = val; }
        void set_pc(uint32_t val) { dut->pc = val; }
        void set_imm(uint32_t val) { dut->imm = val; }
        void set_rs1(uint32_t val) { dut->rs1 = val; }
        void set_rs2(uint32_t val) { dut->rs2 = val; }
        void set_rd_i(uint32_t val) { dut->rd_i = val; }
        void set_ctrl(uint32_t val) { dut->ctrl_word_i = val; }
        void set_update(uint32_t val) { dut->update = val; }
        void set_value(uint32_t val) { dut->value = val; }
        void set_dest(uint32_t val) { dut->dest = val; }

        bool dispatch() { return dut->dispatch; }
        uint32_t ctrl_word_o() { return dut->ctrl_word_o; }
        uint32_t in1() { return dut->in1; }
        uint32_t in2() { return dut->in2; }
        uint32_t rd_o() { return dut->rd_o; }

        bool full() { return dut->full; }

        int run_tests(int);
};

}

#endif
