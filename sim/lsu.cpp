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
        (int64_t)1 << 35,                 // sb
        0
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
        instr_t *prog = (instr_t *)malloc(cycles * sizeof(instr_t));

        for (int i = 0; i < cycles; i++) {
                prog[i].ctrl = ctrls[rand() % (sizeof(ctrls)/sizeof(int64_t))];
                prog[i].rs1 = rand() % 128;
                prog[i].rs2 = rand() % 128;
                prog[i].imm = rand() % 128;
                prog[i].state = NEW;
                prog[i].rd = rand() % 32;
                prog[i].canon_result = 0;
                prog[i].verif_result = 0;
        }

        std::cout << std::hex;
        
#ifdef DEBUG
        std::cout << "\nProgram:" << std::endl;
#endif

        // Generate 'canon' final dmem state
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
                        prog[i].canon_result = dmem_canon[addr];
#ifdef DEBUG
                        std::cout << " ld 0x" << addr << " -> x" << prog[i].rd;
#endif
                        break;
                case sw:
                case sh:
                case sb:
                        dmem_canon[addr] = (uint8_t)data;
#ifdef DEBUG
                        std::cout << " st x" << prog[i].rd << " -> 0x" << addr;
#endif
                        break;
                default:;
                }

#ifdef DEBUG
                std::cout << std::endl;
#endif
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
                                int range = d_head - i_head + 1;
                                range = rand() % range;
                                issue_idx += range;
                        } while (prog[issue_idx].state >= ISSUED);

                        // If issue_idx is d_head, skip. Gives a slight chance
                        // of skipping issue this cycle, highest if close behind
                        if (issue_idx != d_head) {
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

                // Respond to load requests immediately
                if (dut->ld_en) {
                        dut->ld_ready = 1;
                        dut->ld_data = dmem_verif[dut->ld_addr];
                }

                // Complete stores
                if (dut->st_en) {
                        dmem_verif[dut->st_addr] = (uint8_t)dut->st_data;
                }

                pulse();
                clear();
        }

        
        // Continue running until the queue is cleared
        for (int i = 0; i < 64; i++) {
                if (dut->ld_en) {
                        dut->ld_ready = 1;
                        dut->ld_data = dmem_verif[dut->ld_addr];
                }

                if (dut->st_en) {
                        dmem_verif[dut->st_addr] = (uint8_t)dut->st_data;
                }

                pulse();
                clear();
        }

#ifdef DEBUG
        std::cout << "\nFinal DMEM State:" << std::endl;
#endif

        int status = 0;

        for (int i = 0; i < 256; i++) {
                if (dmem_canon[i] != dmem_verif[i]) {
#ifdef DEBUG
                        std::cout << "[0x" << i << "] = (canon) 0x"
                                << (int)dmem_canon[i] << ", (verif) 0x"
                                << (int)dmem_verif[i] << std::endl;
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
        dut->dispatch_tag = tag & 0x3f;
        dut->new_prd = prd;
        dut->ctrl_word = ctrl;
}

void lsu::issue(int tag, int32_t rs1, int32_t rs2, int32_t imm)
{
        dut->issue = 1;
        dut->issue_tag = tag & 0x3f;
        dut->rs1_val = rs1;
        dut->rs2_val = rs2;
        dut->imm = imm;
}

void lsu::commit(int store)
{
        dut->commit = 1;
        dut->commit_store = store & 0x1;
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
