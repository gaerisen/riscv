#ifndef ROB_HPP
#define ROB_HPP

#include "device.hpp"

namespace sim
{

struct rob : public device {

        rob(std::shared_ptr<VerilatedContext> ctx);
        ~rob();

        uint32_t ptr() { return dut->issued_ptr; };
        bool commit() { return dut->commit; };
        bool branch() { return dut->branch; };
        bool store() { return dut->store; };
        uint32_t rd() { return dut->rd; };
        uint32_t wb() { return dut->wb; };

        int run_tests(int);
};

} // namespace sim
  
#endif // ROB_HPP
