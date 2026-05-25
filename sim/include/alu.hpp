#ifndef ALU_HPP
#define ALU_HPP

#include "device.hpp"
#include "generator.hpp"

namespace sim
{

struct alu : public device {
        alu(std::shared_ptr<VerilatedContext> ctx);
        ~alu();

        void flush(int);
        void stall(int);

        void set_ctrl(unsigned long long);
        void set_rs1val(int);
        void set_rs2val(int);
        void set_imm(int);
        void set_pc(int);

        int get_result();
        bool get_branch();

        void run_tests();
};

} // namespace sim

#endif // ALU_HPP
