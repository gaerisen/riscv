#ifndef DEVICE_HPP
#define DEVICE_HPP

#include "Vtop.h"

namespace rv32 {

struct Device {
        Vtop* dut;

        int cycles;

        Device();
        ~Device();

        void pulse();
        void reset(int);
};

}

#endif // DEVICE_HPP
