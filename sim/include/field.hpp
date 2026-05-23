#ifndef FIELD_HPP
#define FIELD_HPP

#include <cstddef>
#include <stdexcept>
#include "types.hpp"

namespace sim
{

struct field {
        field_mode_e mode;

        int lsb;

        int value;

        int *lut;
        size_t lut_len;

        int range_lo;
        int range_hi;

        int mask;

        field(int lsb, field_mode_e mode);

        void set_val(int val);
        void set_lut(int *p, size_t len);
        void set_range(int lo, int hi);
        void set_mask(int mask);

        unsigned int generate();
};

} // namespace sim

#endif // FIELD_HPP
