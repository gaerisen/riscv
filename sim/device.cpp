#include "device.hpp"

namespace sim
{

device::device(std::shared_ptr<VerilatedContext> ctx) :
        ctx(ctx),
        dut(std::make_unique<Vtop>(ctx.get(), "top")),
        cycles(0)
{
        dut->clk = 0;
        dut->rst = 0;
}

device::~device()
{
        dut->final();
}

void device::pulse()
{
        dut->clk = 1;
        ctx->timeInc(1);
        dut->eval();

        dut->clk = 0;
        ctx->timeInc(1);
        dut->eval();

        cycles++;
        return;
}

void device::reset(int n)
{
        dut->rst = 1;

        for (int i = 0; i < n; i++) {
                pulse();
        }

        dut->rst = 0;

        return;
}

} // namespace sim
