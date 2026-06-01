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


        try {
                int status;

                seed = time(0); // Get current time
                srand(seed);    // Set time as seed
                seed = rand();  // Get random num as new seed
                srand(seed);    // Set seed

                for (int i = 0; i < 8096; i++) {
                        std::cout << "\nSeed: " << seed << std::endl;
                        status = dut.run_tests(1024);
                        if (status != 0) return status;
                        srand(++seed);
                } 

                std::cout << "All done!" << std::endl;
/*
                srand(0x47e9b32b);
                dut.run_tests(256); */


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
