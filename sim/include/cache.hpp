#ifndef CACHE_HPP
#define CACHE_HPP

#include "device.hpp"

namespace sim
{

struct cache : public device {

        cache(std::shared_ptr<VerilatedContext> ctx);
        ~cache();

        int req_read(int);
        void req_write(int, int);

        int run_tests(int);
};

} // namespace sim

#endif // CACHE_HPP
