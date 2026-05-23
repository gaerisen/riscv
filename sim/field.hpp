#ifndef FIELD_HPP
#define FIELD_HPP

#include <cstddef>
#include <stdexcept>
#include "types.hpp"

struct field {
        field_mode_e mode;

        int lsb;

        int value;

        int *lut;
        size_t lut_len;

        int range_lo;
        int range_hi;

        int mask;

        field(int lsb, field_mode_e mode) :
                lsb(lsb), mode{mode}, lut{nullptr}, range_lo{0},
                range_hi{0}, mask{0}
        {}

        void set_val(int val)
        {
                if (mode != DEFINED) {
                        throw new std::runtime_error(
                                        "Attempted to set_val on a field not"
                                        " in DEFINED mode");
                }

                value = val;
        }

        void set_lut(int *p, size_t len)
        {
                if (mode != RAND_LUT) {
                        throw new std::runtime_error(
                                        "Attempted to set_lut on a field not"
                                        " in RAND_LUT mode");
                }

                lut = p;
                lut_len = len;
        }

        void set_range(int lo, int hi)
        {
                if (mode != RAND_RANGE) {
                        throw new std::runtime_error(
                                        "Attempted to set_range on a field not"
                                        " in RAND_RANGE mode");
                }
                
                range_lo = lo;
                range_hi = hi;
        }

        void set_mask(int mask)
        {
                if (mode != RAND_MASK) {
                        throw new std::runtime_error(
                                        "Attempted to set_mask on a field not"
                                        " in RAND_MASK mode");
                }
                
                this->mask = mask;
        }
};

#endif // FIELD_HPP
