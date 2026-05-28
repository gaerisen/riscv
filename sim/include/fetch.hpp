#ifndef FETCH_HPP
#define FETCH_HPP

#include "device.hpp"

namespace sim
{

struct fetch : public device {

        fetch(std::shared_ptr<VerilatedContext> ctx);
        ~fetch();

        int get_pc();
        int get_instr();
        bool get_valid();

        void set_i_data_ready(int);
        void set_i_data_i(int);

        void set_branch(bool);
        void set_jump(bool);
        void set_system(int);

        void set_alu_result(int);
        void set_mtvec(int);
        void set_mepc(int);

        void run_tests(int);
};

} // namespace sim

#endif // FETCH_HPP
