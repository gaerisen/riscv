#include "field.hpp"

namespace sim
{

field::field(int lsb, field_mode_e mode) :
        lsb(lsb), mode{mode}, lut{nullptr}, range_lo{0},
        range_hi{0}, mask{0}
{}

void field::set_val(int val)
{
        if (mode != DEFINED) {
                throw std::runtime_error(
                                "Attempted to set_val on a field not"
                                " in DEFINED mode");
        }

        value = val;
}

void field::set_lut(int *p, size_t len)
{
        if (mode != RAND_LUT) {
                throw std::runtime_error(
                                "Attempted to set_lut on a field not"
                                " in RAND_LUT mode");
        }

        lut = p;
        lut_len = len;
}

void field::set_range(int lo, int hi)
{
        if (mode != RAND_RANGE) {
                throw std::runtime_error(
                                "Attempted to set_range on a field not"
                                " in RAND_RANGE mode");
        }
        
        range_lo = lo;
        range_hi = hi;
}

void field::set_mask(int mask)
{
        if (mode != RAND_MASK) {
                throw std::runtime_error(
                                "Attempted to set_mask on a field not"
                                " in RAND_MASK mode");
        }
        
        this->mask = mask;
}

unsigned int field::generate()
{
        switch (mode) {
        case DEFINED:
                return value;
        case RAND_LUT:
                if (!lut) {
                        throw std::runtime_error(
                                "Attempted to generate from undefined LUT");
                }
                return lut[rand() % lut_len];
        case RAND_RANGE:
                return range_lo + (rand() % (range_hi - range_lo + 1));
        case RAND_MASK:
                return rand() & mask;
        default:
                throw std::runtime_error(
                                "Attempted to generate a field with undefined"
                                " mode");
        }
}

} // namespace sim
