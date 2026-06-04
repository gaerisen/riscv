#include "cache.hpp"

namespace sim
{
cache::cache(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

cache::~cache()
{}

int cache::req_read(int addr) { return 0; }
void cache::req_write(int addr, int op)
{
        switch (op) {
                case 0:; // sb
                case 1:; // sh
                case 2:; // sw
                default:;
        }
}

} // namespace sim
