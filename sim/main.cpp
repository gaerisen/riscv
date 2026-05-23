#include <verilated.h>
#include <iostream>
#include <iomanip>
#include <cstdlib>
#include <cstdint>
#include <ctime>

#include "generator.hpp"

struct sim::generator gen;

int opcodes[] = {
        0b01101, // lui
        0b00101, // auipc
        0b11011, // jal
        0b11001, // jalr
        0b11000, // branch
        0b00000, // load
        0b01000, // store
        0b00100, // alui
        0b01100, // alur
        0b00011, // fence
        0b11100  // system
};

int main(int argc, char *argv[])
{
        srand(time(0));

        try {
                int idx;

                idx = gen.add_field(2, 0, DEFINED);
                gen.fields.at(idx).set_val(0b11);

                idx = gen.add_field(6, 2, RAND_LUT);
                gen.fields.at(idx).set_lut(opcodes, 11);

                for (int i = 0; i < 32; i++) {
                        std::cout << std::hex << gen.generate() << std::endl;
                }
        } catch (const std::runtime_error& e) {
                std::cerr << "RUNTIME: " << e.what();
                return 1;
        } catch (const std::exception& e) {
                std::cerr << "EXCEPTION: " << e.what();
                return 1;
        } catch (...) {
                std::cerr << "Caught unexpected exception" << std::endl;
                return 1;
        }

        return 0;
}
