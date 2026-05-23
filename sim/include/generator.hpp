#ifndef GENERATOR_HPP
#define GENERATOR_HPP

#include <vector>
#include "types.hpp"
#include "field.hpp"

// Generator struct
//
// Desired properties: The ability to add and define the characteristics of
// different fields contributing to the overall output;
//
// add_field: designate a range of bits for one field, maybe return an
// identifier for management. Inputs are upper/lower bounds of field (need error
// checking for overlap), and mode (defined, random from lut, random in range,
// random from mask)
//
// RFL needs set_lut(int *p, size_t len)
// RIR needs set_range(int lo, int hi)
// RFM needs set_mask(int mask)

namespace sim {

struct generator {
        int field_mask;
        std::vector<struct field> fields;

        generator();

        int add_field(int, int, field_mode_e);

        unsigned int generate();
};

} // namespace sim

#endif // GENERATOR_HPP
