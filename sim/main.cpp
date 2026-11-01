#include <verilated.h>
#include <iostream>
#include <cstdlib>
#include <ctime>

#include "lsu.hpp"

#define TRIALS 256

int main(int argc, char *argv[])
{
        auto ctx = std::make_shared<VerilatedContext>();
        ctx->traceEverOn(true);

        sim::lsu dut(ctx);

        srand(time(0));
        int seed;
        int ret;
        uint64_t cycles = 0;

        try {

#ifdef SEED
        srand(SEED);
        ret = dut.run_tests(2048);
        std::cout << "Cycles: " << dut.cycles << std::endl;
#else
        for (int i = 0; i < TRIALS; i++) {
                seed = rand();
                std::cout << "Trial #" << i+1 << "; Seed: " << seed << std::endl;
                srand(seed);

                ret = dut.run_tests(2048);
                cycles += dut.cycles;

                if (ret != 0) {
                        std::cout << "Failed, exiting..." << std::endl;
                        return ret;
                }
        }
        
        std::cout << "Average cycles: " << cycles / TRIALS << std::endl;
#endif

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
