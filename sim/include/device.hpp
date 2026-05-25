#ifndef DEVICE_HPP
#define DEVICE_HPP

#include "Vtop.h"

namespace sim
{

struct device {
        std::shared_ptr<VerilatedContext> ctx;
        std::unique_ptr<Vtop> dut;

        int cycles;

        device(std::shared_ptr<VerilatedContext>);
        ~device();

        void pulse();
        void reset(int);
};

} // namespace sim

#endif // DEVICE_HPP
