#include "generator.hpp"
#include "field.hpp"
#include <stdexcept>

namespace sim
{

generator::generator() :
        field_mask{0}
{}

int generator::add_field(int hi, int lo, field_mode_e mode)
{
        int new_mask = ((2 << hi) - 1) ^
                        ((2 << lo) - 1);

        if (new_mask & field_mask) {
                throw std::runtime_error("Overlap with an existing field");
        }

        field_mask |= new_mask;

        fields.push_back(field(lo, mode));

        return fields.size() - 1;
}

int generator::add_field(int hi, int lo, int val)
{
        int new_mask = ((2 << hi) - 1) ^
                        ((2 << lo) - 1);

        if (new_mask & field_mask) {
                throw std::runtime_error("Overlap with an existing field");
        }

        field_mask |= new_mask;

        fields.push_back(field(lo, DEFINED));
        fields.back().set_val(val);

        return fields.size() - 1;
}

int generator::add_field(int hi, int lo, int *p, size_t len)
{
        int new_mask = ((2 << hi) - 1) ^
                        ((2 << lo) - 1);

        if (new_mask & field_mask) {
                throw std::runtime_error("Overlap with an existing field");
        }

        field_mask |= new_mask;

        fields.push_back(field(lo, RAND_LUT));
        fields.back().set_lut(p, len);

        return fields.size() - 1;
}

int generator::add_field(int hi, int lo, int range_lo, int range_hi)
{
        int new_mask = ((2 << hi) - 1) ^
                        ((2 << lo) - 1);

        if (new_mask & field_mask) {
                throw std::runtime_error("Overlap with an existing field");
        }

        field_mask |= new_mask;

        fields.push_back(field(lo, RAND_RANGE));
        fields.back().set_range(range_lo, range_hi);

        return fields.size() - 1;
}

unsigned int generator::generate()
{
        unsigned int out = 0;

        for (auto f : fields) {
                auto f_gen = f.generate();
                out |= f_gen << f.lsb;
        }

        return out;
}

} // namespace sim
