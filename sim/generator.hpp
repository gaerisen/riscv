#ifndef GENERATOR_HPP
#define GENERATOR_HPP

#include <vector>
#include "types.hpp"

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


struct field;

struct generator {
        int field_mask;
        std::vector<struct field> fields;

        int add_field(int, int, field_mode_e);

        unsigned int generate();
};

#endif // GENERATOR_HPP
