#ifndef DEVICE_HPP
#define DEVICE_HPP

#include "Vdecoder.h"

struct device {
        Vdecoder* dut;

        int cycles;

        device();
        ~device();

        void pulse();
        void reset(int);
};

#endif // DEVICE_HPP
