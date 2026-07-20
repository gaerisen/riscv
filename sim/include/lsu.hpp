#ifndef LSU_HPP
#define LSU_HPP

#include "device.hpp"

namespace sim
{

struct lsu : public device {

        lsu(std::shared_ptr<VerilatedContext> ctx);
        ~lsu();

        int run_tests(int);
};

} // namespace sim

#endif // LSU_HPP
