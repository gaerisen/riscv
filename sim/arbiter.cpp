#include "arbiter.hpp"

// ctrl word macros
#define ld ((int64_t)1 << 36)
#define sw (((int64_t)1 << 35) | (1 << 8))
#define sh (((int64_t)1 << 35) | (1 << 7))
#define sb ((int64_t)1 << 35)

#define store(x) ((x & ((int64_t)1 << 35)) >> 35)

#define byte3(x) ((x & (0xff << 24)) >> 24)
#define byte2(x) ((x & (0xff << 16)) >> 16)
#define byte1(x) ((x & (0xff << 8)) >> 8)
#define byte0(x) (x & 0xff)

typedef struct {
	bool store;
	bool load;
	uint32_t stdata;
	uint32_t staddr;
	uint32_t ldaddr;
} instr_t;

namespace sim
{

arbiter::arbiter(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

arbiter::~arbiter()
{}

int arbiter::run_tests(int cycles)
{
        // Make and initialize dmem
        uint32_t dmem_canon[256];
        uint32_t dmem_verif[256];
	int errors = 0;

	reset(5);

        for (int i = 0; i < 256; i++) {
                dmem_canon[i] = 0;
                dmem_verif[i] = 0;
        }

        // Generate random "prog"
        instr_t *prog = (instr_t *)malloc(cycles * sizeof(instr_t));

        for (int i = 0; i < cycles; i++) {
		prog[i].store = rand() % 2;
		prog[i].load = rand() % 2;
		prog[i].stdata = rand();
		prog[i].staddr = (rand() & 255);
		prog[i].ldaddr = (rand() & 255);
        }	

	// Canon run
	for (int i = 0; i < cycles; i++) {
		if (prog[i].store) {
			dmem_canon[prog[i].staddr] = prog[i].stdata;
		}
	}

	// DUT run
	for (int i = 0; i < cycles; i++) {
		if (prog[i].store) {
			request_store(prog[i].staddr, prog[i].stdata);
		}
		if (prog[i].load) {
			request_load(prog[i].ldaddr);
		}

		// Store case
		if (dut->d_valid && dut->d_we) {
			dmem_verif[dut->d_addr] = dut->d_data_o;
		}
		if (dut->d_valid && !dut->d_we) {
			service_load(dmem_verif[dut->d_addr]);
		}

		pulse();
		clear();
	}

	// DUT cleanup pipeline
	for (int i = 0; i < 10; i++) {
		// Store case
		if (dut->d_valid && dut->d_we) {
			dmem_verif[dut->d_addr] = dut->d_data_o;
		}
		if (dut->d_valid && !dut->d_we) {
			service_load(dmem_verif[dut->d_addr]);
		}

		pulse();
		clear();
	}


	// Compare dmems
	for (int i = 0; i < 256; i++) {
		if (dmem_canon[i] != dmem_verif[i]) {
			errors++;
		}
	}

	return errors;
}

void arbiter::service_load(uint32_t data)
{
	dut->d_ready = 1;
	dut->d_data_i = data;
	dut->ld_en = 0;
	dut->ld_addr = 0;
}

void arbiter::request_load(uint32_t addr)
{
	dut->ld_en = 1;
	dut->ld_addr = addr;
}

void arbiter::request_store(uint32_t addr, uint32_t data)
{
	dut->st_en = 1;
	dut->st_addr = addr;
	dut->st_data = data;
	dut->st_op = 2;
}

void arbiter::clear()
{
	dut->st_en = 0;
	dut->st_addr = 0;
	dut->st_data = 0;
	dut->st_op = 0;
}

}
