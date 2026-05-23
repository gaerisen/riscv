#ifndef DEVICE_HPP
#define DEVICE_HPP

#include "Vtop.h"

struct device {
        Vtop* dut;

        int cycles;

        device();
        ~device();

        void pulse();
        void reset(int);
};

#endif // DEVICE_HPP
