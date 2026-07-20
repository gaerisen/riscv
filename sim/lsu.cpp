#include "lsu.hpp"

// ctrl word macros
#define ld ((int64_t)1 << 36)
#define sw (((int64_t)1 << 35) | (1 << 8))
#define sh (((int64_t)1 << 35) | (1 << 7))
#define sb ((int64_t)1 << 35)

namespace sim
{

lsu::lsu(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

lsu::~lsu()
{}

int lsu::run_tests(int cycles)
{
        uint8_t dmem [256];

        for (int i = 0; i < 256; i++) {
                dmem[i] = 0;
        }

        // === in-order load-store-load test ===
        dispatch(0, 2, ld);
        iter();

        dispatch(1, 0, sw);
        issue(0, 0, 0, 8);
        iter();

        dispatch(2, 4, ld);
        issue(1, 4, 69, 4);
        iter();

        issue(2, 8, 0, 0);
        iter();

        iter();

        load(dmem[dut->ld_addr]);
        iter();

        iter();
        iter();
        iter();

        commit(1);
        iter();

        dmem[dut->st_addr] = (uint8_t)dut->st_data;

        iter();
        iter();

        load(dmem[dut->ld_addr]);
        iter();

        iter();
        iter();
        iter();

        return 0;
}

void lsu::clear()
{
        dut->dispatch = 0;
        dut->issue = 0;
        dut->commit = 0;
        dut->ld_ready = 0;
}

void lsu::dispatch(int tag, int prd, int64_t ctrl)
{
        dut->dispatch = 1;
        dut->dispatch_tag = tag;
        dut->new_prd = prd;
        dut->ctrl_word = ctrl;
}

void lsu::issue(int tag, int32_t rs1, int32_t rs2, int32_t imm)
{
        dut->issue = 1;
        dut->issue_tag = tag;
        dut->rs1_val = rs1;
        dut->rs2_val = rs2;
        dut->imm = imm;
}

void lsu::commit(int tag)
{
        dut->commit = 1;
        dut->commit_tag = tag;
}

void lsu::load(int32_t data)
{
        dut->ld_ready = 1;
        dut->ld_data = data;
        std::cout << "DMEM accepts request" << std::endl;
}

void lsu::iter()
{
        std::cout << "[" << cycles << "] ";

        if (dut->dispatch) {
                std::cout << "\tDispatch: tag=" << dut->dispatch_tag
                        << ", prd=" << dut->new_prd
                        << ", store=" << ((dut->ctrl_word & sw) >> 35)
                        << std::endl;
        }

        if (dut->issue) {
                std::cout << "\tIssue: tag=" << dut->issue_tag
                        << ", rs1=" << dut->rs1_val
                        << ", rs2=" << dut->rs2_val
                        << ", imm=" << dut->imm << std::endl;
        }

        if (dut->commit) {
                std::cout << "\tCommit: tag=" << dut->commit_tag << std::endl;
        }

        pulse();

        if (dut->update) {
                std::cout << "\tCDB: tag=" << dut->update_tag
                        << ", prd=" << dut->update_prd
                        << ", data=" << dut->update_data << std::endl;
        }

        if (dut->st_en) {
                std::cout << "\tStore: addr=" << dut->st_addr
                        << ", data=" << dut->st_data << std::endl;
        }

        if (dut->ld_en) {
                std::cout << "\tLoad request: addr=" << dut->ld_addr
                        << std::endl;
        }

        std::cout << std::endl;
        clear();
}

} // namespace sim
