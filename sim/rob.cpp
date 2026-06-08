#include "rob.hpp"
#include <cstdint>

void shuffle(int[], int[], size_t);

#define ENTRIES 256

int rds[ENTRIES];
int rds_shuf[ENTRIES];

namespace sim
{

rob::rob(std::shared_ptr<VerilatedContext> ctx) :
        device(ctx)
{
        dut->issue = 0;
        dut->issued_dest = 0;
        dut->issued_ctrl = 0;

        dut->update_entry = 0;
        dut->result = 0;
        dut->entry_idx = 0;
}

rob::~rob()
{}

int rob::run_tests(int cycles)
{

        bool issue = false;
        uint64_t ctrl;
        uint32_t dest;

        bool issue_dly = false;
        uint32_t tail_idx = 0;
        
        bool update = false;
        uint32_t result;
        uint32_t update_idx;

        reset(5);

        issue = true;

        for (int i = 0; i < ENTRIES; i++)
                rds[i] = i;

        shuffle(rds, rds_shuf, ENTRIES);

        int issue_idx = 0;
        int result_idx = 0;
        int commit_rd = 0;

        int status = 0;
        
        for (int i = 0; i < cycles; i++) {
                if ((issue_idx < ENTRIES) && !full()) {
                        dut->issued_dest = rds[issue_idx];
                        dut->issue = true;
                        issue_idx++;
                } else {
                        dut->issued_dest = 0;
                        dut->issue = false;
                }

                if ((i < 5) || (result_idx > ENTRIES - 1)) {
                        dut->update_entry = false;
                        dut->entry_idx = 0;
                } else {
                        dut->update_entry = (rand() % 4) != 0;
                        if (dut->update_entry) {
                                dut->entry_idx = rds_shuf[result_idx] % 64;
                                result_idx++;
                        }
                }

                if (i == 32) dut->flush = 1;
                else dut->flush = 0;

                pulse();

                if (commit()) {
                        if (rd() != commit_rd) {
                                status = 1;
                                std::cout << "Failed; got " << rd()
                                        << ", expected " << commit_rd
                                        << std::endl;
                        }
                        commit_rd++;
                }
        }
        
        if (result_idx < ENTRIES - 1) status = 1;

        return status;
}

}

// Reproducable and local shuffling algorithm
void shuffle(int src[], int dest[], size_t size)
{
        for (size_t i = 0; i < size; i++) {
                dest[i] = src[i];
        }
        
        size_t swap;
        int tmp;

        for (size_t i = 0; i < size; i++) {
                swap = i + (rand() % 3);
                if (swap >= size) swap = size-1;
                tmp = dest[swap];
                dest[swap] = dest[i];
                dest[i] = tmp;
        }
}
