#include "rat.hpp"

namespace sim
{

rat::rat(std::shared_ptr<VerilatedContext> ctx) :
        device(ctx)
{
}

rat::~rat()
{}

int rat::run_tests(int cycles)
{
        reset(5);

        std::vector<uint32_t> rds;

        // Prime everything with 3 cycles of random input
        
        set_commit(false);
        set_free_prd(0);

        set_rs1(rand() % 32);
        set_rs2(rand() % 32);
        set_rd(rand() % 32);
        pulse();
        rds.push_back(prd_old());

        set_rs1(rand() % 32);
        set_rs2(rand() % 32);
        set_rd(rand() % 32);
        pulse();
        rds.push_back(prd_old());

        set_rs1(rand() % 32);
        set_rs2(rand() % 32);
        set_rd(rand() % 32);
        pulse();

        set_commit(true);
        auto rds_iter = rds.begin() + (rand() % rds.size());
        set_free_prd(*rds_iter);
        rds.erase(rds_iter);

        rds.push_back(prd_old());

        for (int i = 0; i < cycles; i++) {
                set_rs1(rand() % 32);
                set_rs2(rand() % 32);
                set_rd(rand() % 32);

                pulse();

                rds_iter = rds.begin() + (rand() % rds.size());

                set_free_prd(*rds_iter);
                rds.erase(rds_iter);

                rds.push_back(prd_old());
        }

        return 0;
}

}
