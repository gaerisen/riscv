#ifndef LSU_HPP
#define LSU_HPP

#include "device.hpp"
#include <cstdint>

namespace sim
{

struct lsu : public device {

        lsu(std::shared_ptr<VerilatedContext> ctx);
        ~lsu();

        void clear();

        void dispatch(int tag, int prd, int64_t ctrl);
        void issue(int tag, int32_t rs1, int32_t rs2, int32_t imm);
        void commit(int tag);

        void load(int32_t data);

        void iter();

        int run_tests(int);
};

} // namespace sim

#endif // LSU_HPP
