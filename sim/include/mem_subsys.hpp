#ifndef MEM_SUBSYS_HPP
#define MEM_SUBSYS_HPP

#include "device.hpp"

namespace sim
{

struct mem_subsys : public device {

        mem_subsys(std::shared_ptr<VerilatedContext> ctx);
        ~mem_subsys();

        int run_tests(int);

        void clear();

        void dispatch(int tag, int prd, int64_t ctrl);
        void issue(int tag, int32_t rs1, int32_t rs2, int32_t imm);
        void commit(int tag);

        void load(int32_t data);

        void iter();
};

} // namespace sim

#endif // MEM_SUBSYS_HPP
