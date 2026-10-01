#ifndef ARBITER_HPP
#define ARBITER_HPP

#include "device.hpp"
#include <cstdint>

namespace sim
{

struct arbiter : public device {

        arbiter(std::shared_ptr<VerilatedContext> ctx);
        ~arbiter();

	void service_load(uint32_t);

	void request_load(uint32_t);
	void request_store(uint32_t, uint32_t);

	void clear();

        int run_tests(int);
};

} // namespace sim

#endif // ARBITER_HPP
