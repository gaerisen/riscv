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
