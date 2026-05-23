#include "device.hpp"

device::device()
{
        dut = new Vtop;
        dut->clk = 0;
        dut->rst = 0;
        cycles = 0;
}

device::~device()
{
        dut->finish();
        delete dut;
}

void device::pulse()
{
        dut->clk = 1;
        dut->eval();
        dut->clk = 0;
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
