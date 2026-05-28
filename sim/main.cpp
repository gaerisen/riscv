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
        srand(time(0));

        try {

                dut.run_tests(1000);

                ctx->coveragep()->write("logs/coverage.dat");

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
