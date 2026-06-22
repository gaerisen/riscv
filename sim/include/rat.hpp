#ifndef RAT_HPP
#define RAT_HPP

#include "device.hpp"

namespace sim
{

struct rat : public device {
        rat(std::shared_ptr<VerilatedContext> ctx);
        ~rat();

        void set_rs1(uint32_t val) { dut->rs1 = val; }
        void set_rs2(uint32_t val) { dut->rs2 = val; }
        void set_rd(uint32_t val) { dut->rd = val; }

        uint32_t prs1() { return dut->prs1; }
        uint32_t prs2() { return dut->prs2; }
        uint32_t prd_old() { return dut->prd_old; }
        uint32_t prd_new() { return dut->prd_new; }

        void set_commit(bool val) { dut->commit = val; }
        void set_free_prd(uint32_t val) { dut->free_prd = val; }

        int run_tests(int);
};

}

#endif
