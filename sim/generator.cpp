#include "generator.hpp"
#include "field.hpp"
#include <stdexcept>

int generator::add_field(int hi, int lo, field_mode_e mode)
{
        int new_mask = ((2 << hi) - 1) -
                        ((2 << hi) - 1);

        if (new_mask | field_mask) {
                throw new std::runtime_error("Overlap with an existing field");
        }

        field_mask |= new_mask;

        fields.push_back(field(lo, mode));

        return fields.size();
}



