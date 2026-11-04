#include <verilated.h>
#include <iostream>
#include <cstdlib>
#include <ctime>

#include "mem_subsys.hpp"

int main(int argc, char *argv[])
{
        auto ctx = std::make_shared<VerilatedContext>();
        ctx->traceEverOn(true);

        sim::mem_subsys dut(ctx);

        srand(time(0));
        int seed;
        int ret;

        try {

		ret = dut.run_tests(2048);

        } catch (const std::runtime_error& e) {
                std::cerr << "RUNTIME: " << e.what();
                return 1;
        } catch (const std::exception& e) {
                std::cerr << "EXCEPTION: " << e.what();
                return 1;
        } catch (...) {
                std::cerr << "Caught unexpected exception" << std::endl;
                return 1;
        }

        return ret;
}
