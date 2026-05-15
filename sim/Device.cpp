#include "Device.hpp"

namespace rv32 {

Device::Device()
{
        dut = new Vtop;
        dut->clk = 0;
        dut->rst = 0;
        cycles = 0;
}

Device::~Device()
{
        dut->finish();
        delete dut;
}

void Device::pulse()
{
        dut->clk = 1;
        dut->eval();
        dut->clk = 0;
        dut->eval();

        cycles++;
        return;
}

void Device::reset(int n)
{
        dut->rst = 1;

        for (int i = 0; i < n; i++) {
                pulse();
        }

        dut->rst = 0;

        return;
}

}
