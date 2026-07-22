#include <verilated.h>
#include <iostream>
#include <cstdlib>
#include <ctime>

#include "lsu.hpp"

int main(int argc, char *argv[])
{
        auto ctx = std::make_shared<VerilatedContext>();
        ctx->traceEverOn(true);

        sim::lsu dut(ctx);

        srand(time(0));
        int seed;

        try {

/*        for (int i = 0; i < 32; i++) {
                seed = rand();
                std::cout << "Trial #" << i+1 << "; Seed: " << seed << std::endl;
                srand(seed);

                ret = dut.run_tests(2048);

                if (ret != 0) {
                        std::cout << "Failed, exiting..." << std::endl;
                        return ret;
                }
        } */

                seed = rand();
                std::cout << "Seed: " << seed << std::endl;
                srand(seed);

                return dut.run_tests(32);

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

        return 0;
}
