#ifndef DEVICE_HPP
#define DEVICE_HPP

#include "Vtop.h"

namespace sim
{

struct device {
        Vtop* dut;

        int cycles;

        device();
        ~device();

        void pulse();
        void reset(int);
};

} // namespace sim

#endif // DEVICE_HPP
