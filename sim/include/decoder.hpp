#ifndef DECODER_HPP
#define DECODER_HPP

#include "device.hpp"

namespace sim
{

struct decoder : public device {
        decoder();
        ~decoder();

        void flush(int);
        void stall(int);

        void set_instr(unsigned int i) { dut->instr_i = i; }

        unsigned int get_rs1() { return dut->rs1_o; }
        unsigned int get_rs2() { return dut->rs2_o; }
        unsigned int get_rd() { return dut->rd_o; }
        unsigned int get_imm() { return dut->imm_o; }
};

} // namespace sim

#endif // DECODER_HPP
