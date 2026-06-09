#ifndef FETCH_HPP
#define FETCH_HPP

#include "device.hpp"

namespace sim
{

struct fetch : public device {

        fetch(std::shared_ptr<VerilatedContext> ctx);
        ~fetch();

        int get_i_addr();
        int get_pc();
        int get_instr();
        bool get_valid();
        bool get_flush();

        void set_stall(int);
        void set_i_data_i(int);

        void set_branch(bool);
        void set_branch_taken(bool);
        void set_jump(bool);

        void set_alu_result(int);

        void set_pc_dec(int in);
        void set_pc_exe(int in);

        int run_tests(int);
};

} // namespace sim

#endif // FETCH_HPP
