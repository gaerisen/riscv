#include "decoder.hpp"

namespace sim
{

decoder::decoder()
{
        dut = new Vtop;
        dut->clk = 0;
        dut->rst = 0;
        dut->flush = 0;
        dut->stall = 0;
        dut->instr_i = 0;
        cycles = 0;
}

decoder::~decoder() {}

void decoder::stall(int n)
{
        dut->stall = 1;

        for (int i = 0; i < n; i++) {
                pulse();
        }

        dut->stall = 0;

        return;
}

void decoder::flush(int n)
{
        dut->flush = 1;

        for (int i = 0; i < n; i++) {
                pulse();
        }

        dut->flush = 0;

        return;
}

} // namespace sim
