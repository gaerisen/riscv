#include <verilated.h>
#include <iostream>
#include <cstdlib>
#include <ctime>

#include "cache.hpp"

int main(int argc, char *argv[])
{
        auto ctx = std::make_shared<VerilatedContext>();
        ctx->traceEverOn(true);

        sim::cache dut(ctx);

        srand(time(0));

        try {

                if (dut.run_tests(1024) == 0) {
                        std::cout << "Success" << std::endl;
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
