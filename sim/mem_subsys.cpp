#include "mem_subsys.hpp"
#include "Vtop_mem_subsys.h"
#include "Vtop_dmem.h"

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

#define DEBUG

typedef enum {
        NEW,
        DISPATCHED,
        ISSUED,
        READY,
        COMMITTED
} instr_state_e;

typedef struct {
        int64_t ctrl;
        int rs1;
        int rs2;
        int imm;
        instr_state_e state;
        int rd;
        uint8_t canon_result;
        uint8_t verif_result;
} instr_t;

int64_t ctrls[] = {
        (int64_t)1 << 36,                // load
        (int64_t)1 << 36,                // load
        (int64_t)1 << 35,                  // sb
        (int64_t)1 << 35,                  // sb
        0
};

namespace sim
{

mem_subsys::mem_subsys(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{}

mem_subsys::~mem_subsys()
{}

instr_t *genprog(int cycles)
{
        instr_t *prog = (instr_t *)malloc(cycles * sizeof(instr_t));
	if (!prog) {
		return NULL;
	}

        for (int i = 0; i < cycles; i++) {
                prog[i].ctrl = ctrls[rand() % (sizeof(ctrls)/sizeof(int64_t))];
                prog[i].rs1 = rand() % 64;
                prog[i].rs2 = rand() % 128;
                prog[i].imm = 0;
                prog[i].state = NEW;
                prog[i].rd = rand() % 32;
                prog[i].canon_result = 0;
                prog[i].verif_result = 0;
        }

	return prog;
}

void runcanon(uint8_t *dmem, instr_t *prog, int cycles)
{
        for (int i = 0; i < cycles; i++) {
                int addr = prog[i].rs1 + prog[i].imm;
                int data = prog[i].rs2;

#ifdef DEBUG
                std::cout << "<" << i << ">";

                std::cout << " rs1=" << prog[i].rs1;
                std::cout << " rs2=" << prog[i].rs2;
                std::cout << " imm=" << prog[i].imm;
#endif

                switch (prog[i].ctrl) {
                case ld:
                        prog[i].canon_result = dmem[addr];
#ifdef DEBUG
                        std::cout << "   \tld 0x" << addr << " -> x" << prog[i].rd;
#endif
                        break;
                case sw:
                case sh:
                case sb:
                        dmem[addr] = (uint8_t)data;
#ifdef DEBUG
                        std::cout << "   \tst x" << prog[i].rd << " -> 0x" << addr;
#endif
                        break;
                default:;
                }

#ifdef DEBUG
                std::cout << std::endl;
#endif
        }
}

int mem_subsys::run_tests(int cycles)
{
	// Make and initialize dmem
        uint8_t dmem_canon[64];

        for (int i = 0; i < 64; i++) {
                dmem_canon[i] = 0;
        }

        // Generate random "prog"
        instr_t *prog = genprog(cycles);
        std::cout << std::hex;
	runcanon(dmem_canon, prog, cycles);
        
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
                if (prog[c_head].state == READY) {
                        prog[c_head].state = COMMITTED;
                        commit(store(prog[c_head].ctrl));
                        c_head++;
                }

                // Execute: Add a gap between issue and commit, and record load
                // results
                for (int j = c_head; j < d_head; j++) {
                        if (prog[j].state == ISSUED) {
                                if (prog[j].ctrl == ld) {
                                        if (dut->update &&
                                        (dut->update_tag == (j & 0x3f))) {
                                                prog[j].verif_result = dut->update_data;
                                                prog[j].state = READY;
                                        }
                                } else {
                                        prog[j].state = READY;
                                }
                        }
                }
                
                // Issue: For now in-order, but with a slight chance of failure
                if ((i_head < d_head) && (i_head - c_head < 32)) {
                        // Set issue_idx to a num between i_head and d_head
                        // inclusive
                        int issue_idx;

                        do {
                                issue_idx = i_head;
                                int range = d_head - i_head + 3;
                                range = rand() % range;
                                issue_idx += range;
                        } while (prog[issue_idx].state >= ISSUED);

                        // If issue_idx is d_head, skip. Gives a slight chance
                        // of skipping issue this cycle, highest if close behind
                        if (issue_idx <= d_head) {
                                issue(issue_idx,
                                        prog[issue_idx].rs1,
                                        prog[issue_idx].rs2,
                                        prog[issue_idx].imm);

                                prog[issue_idx].state = ISSUED;

                                // Iterate i_head until reached an unissued op
                                for (; i_head < d_head && prog[i_head].state >= ISSUED; i_head++);
                        }
                }

                // Dispatch
                if ((d_head < cycles) && !(dut->full) && ((d_head - i_head) < 32)) {
                        dispatch(d_head, 0, prog[d_head].ctrl);
                        prog[d_head].state = DISPATCHED;
                        d_head++;
                }

                pulse();
                clear();
        }

        
        // Continue running until the queue is cleared
        for (int i = 0; i < 64; i++) {
                pulse();
                clear();
        }

#ifdef DEBUG
        std::cout << "\nFinal DMEM State:" << std::endl;
#endif

        int status = 0;

        for (int i = 0; i < 64; i++) {
                if (dmem_canon[i] != dut->mem_subsys->dmem->x[i]) {
#ifdef DEBUG
                        std::cout << "[0x" << i << "] = (canon) 0x"
                                << (int)dmem_canon[i] << ", (verif) 0x"
                                << (int)dut->mem_subsys->dmem->x[i] << std::endl;
#endif
                        status++;
                }
        }

#ifdef DEBUG
        std::cout << "\nFinal Program State:" << std::endl;
#endif

        // Compare dmems

        for (int i = 0; i < cycles; i++) {
                if (prog[i].canon_result != prog[i].verif_result) {
#ifdef DEBUG
                        std::cout << "<" << i << "> = (canon) 0x"
                                << (int)prog[i].canon_result << ", (verif) 0x"
                                << (int)prog[i].verif_result << std::endl;
#endif
                        status++;
                }
        }
        
        std::cout << std::dec;

        free(prog);

        return status;
}

void mem_subsys::clear()
{
        dut->dispatch = 0;
        dut->issue = 0;
        dut->commit = 0;
}

void mem_subsys::dispatch(int tag, int prd, int64_t ctrl)
{
        dut->dispatch = 1;
        dut->dispatch_tag = tag & 0x3f;
        dut->new_prd = prd;
        dut->ctrl_word = ctrl;
}

void mem_subsys::issue(int tag, int32_t rs1, int32_t rs2, int32_t imm)
{
        dut->issue = 1;
        dut->issue_tag = tag & 0x3f;
        dut->rs1_val = rs1;
        dut->rs2_val = rs2;
        dut->imm = imm;
}

void mem_subsys::commit(int store)
{
        dut->commit = 1;
        dut->commit_store = store & 0x1;
}

} // namespace sim
