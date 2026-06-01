#ifndef HART_HPP
#define HART_HPP

#include "device.hpp"

namespace sim
{

struct hart : public device {

        hart(std::shared_ptr<VerilatedContext> ctx);
        ~hart();

        void set_i_ready(int in);
        void set_i_data(int in);

        int get_i_addr();

        void print_regfile();

        int run_tests(int);
};

} // namespace sim

#endif // HART_HPP
