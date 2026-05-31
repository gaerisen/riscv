#include <verilated.h>
#include <iostream>
#include <cstdlib>
#include <ctime>

#include "fetch.hpp"

int main(int argc, char *argv[])
{
        auto ctx = std::make_shared<VerilatedContext>();
        ctx->traceEverOn(true);

        struct sim::fetch dut(ctx);

        unsigned long long int seed;

        seed = time(0);
        srand(seed);
        seed = rand();

        std::cout << "Seed: " << seed << std::endl;
        srand(seed);

        try {
                int status;
                
                for (int i = 0; i < 1024; i++) {
                        status = dut.run_tests(128);
                        if (status != 0) break;
                        srand(++seed);
                }

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
