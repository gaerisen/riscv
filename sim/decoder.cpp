#include "decoder.hpp"

namespace sim
{

decoder::decoder(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{
        dut->stall = 0;
        dut->flush = 0;
        dut->instr_i = 0;
}

decoder::~decoder()
{
        dut->final();
}

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
