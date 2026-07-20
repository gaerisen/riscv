#include "lsu.hpp"

namespace sim
{
lsu::lsu(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

lsu::~lsu()
{}

int lsu::run_tests(int cycles)
{
        return 0;
}


} // namespace sim
