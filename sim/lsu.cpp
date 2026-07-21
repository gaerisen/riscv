#include "lsu.hpp"

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

typedef enum {
        NEW,
        DISPATCHED,
        ISSUED,
        EXECUTING,
        COMMITTED
} instr_state_e;

typedef struct {
        int64_t ctrl;
        int32_t rs1;
        int32_t rs2;
        int32_t imm;
        instr_state_e state;
} instr_t;

int64_t ctrls[] = {
        (int64_t)1 << 36,                // load
//        ((int64_t)1 << 35) | (1 << 8),   // sw
//        ((int64_t)1 << 35) | (1 << 7),   // sh
        (int64_t)1 << 35                 // sb
};

namespace sim
{

lsu::lsu(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

lsu::~lsu()
{}

int lsu::run_tests(int cycles)
{
        // Make and initialize dmem
        uint8_t dmem_canon[256];
        uint8_t dmem_verif[256];

        for (int i = 0; i < 256; i++) {
                dmem_canon[i] = 0;
                dmem_verif[i] = 0;
        }

        // Generate random "prog"
        instr_t prog[cycles];

        for (int i = 0; i < cycles; i++) {
                prog[i].ctrl = ctrls[rand() % 2];
                prog[i].rs1 = (rand() % 32) << 2;
                prog[i].rs2 = (rand() % 256);
                prog[i].imm = (rand() % 32) << 2;
                prog[i].state = NEW;
        }

        std::cout << std::hex;

        // Generate 'canon' final dmem state
        for (int i = 0; i < cycles; i++) {
                int addr = prog[i].rs1 + prog[i].imm;
                int data = prog[i].rs2;

                std::cout << "<" << i << "> ";

                switch (prog[i].ctrl) {
                case ld:
                        std::cout << "ld: [" << addr << "] = "
                                << (int)dmem_canon[addr] << std::endl;
                        break;
                case sb:
                        dmem_canon[addr] = (uint8_t)byte0(data);
                        std::cout << "st: [" << addr << "] = "
                                << data << std::endl;
                        break;
                default:;
                }
        }

        /* Out-of-order simulation engine:
         * (1) d(ispatch)_head sends in instructions nonstop sequentially
         *
         * (2) i(ssue)_head tracks the **first** dispatched, non-issued
         * instruction, but any instruction between issue_head and dispatch_head
         * can be selected for issue at a given time
         *
         * (3) c(ommit)_head always stays one entry behind issue_head
         *
         * prog[] array indices are used for ROB tags
         */

        int d_head = 0;
        int i_head = 0;
        int c_head = 0;

        reset(5);

        while (c_head < cycles) {
                // Steps are executed here in 'reverse' order since each one
                // depends on the previous cycle's _head pointers
                
                // Commit: Triggering unconditionally for both load and stores
                // right now. Will have to change when cache misses are
                // introduced
                if (prog[c_head].state == EXECUTING) {
                        commit(c_head++);
                }

                // Execute: Purely symbolic, to insert a 1-cycle gap that would
                // be typical in the actual hart
                for (int j = c_head; j < d_head; j++) {
                        if (prog[j].state == ISSUED) {
                                prog[j].state = EXECUTING;
                        }
                }
                
                // Issue: For now in-order, but with a slight change of failure
                if (i_head < d_head) {
                        if (rand() % 4 != 0) {
                                issue(i_head,
                                        prog[i_head].rs1,
                                        prog[i_head].rs2,
                                        prog[i_head].imm);

                                prog[i_head].state = ISSUED;

                                i_head++;
                        }
                }

                dut->ld_data = i_head;

                // Dispatch
                if (d_head < cycles) {
                        dispatch(d_head, 0, prog[d_head].ctrl);
                        prog[d_head].state = DISPATCHED;
                        d_head++;
                }

                pulse();
                clear();
        }
        
        std::cout << std::dec;

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
