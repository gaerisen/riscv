#include "rs.hpp"
#include "generator.hpp"

typedef enum {
        ZERO = 0,
        RS1 = 1,
        PC = 2
} src1_e;

typedef enum {
        RS2 = 0,
        IMM = 1
} src2_e;

#define src1(x) (src1_e)(((0b11 << 29) & x) >> 29)
#define src2(x) (src2_e)(((0b1 << 28) & x) >> 28)

namespace sim
{

rs::rs(std::shared_ptr<VerilatedContext> ctx) :
        device(ctx)
{
}

rs::~rs()
{}

int rs::run_tests(int cycles)
{
        uint64_t ctrl = 0;
        uint8_t last_rd = 0;

        reset(5);

        set_issue(true);
        ctrl = 2 << 29;  // pc
        ctrl |= (1 << 28); // imm
        set_pc(0xdead);
        set_imm(0xbeef);
        set_ctrl(ctrl);
        pulse();

        ctrl = 0 << 29;  // zero
        ctrl |= (1 << 28); // imm
        set_ctrl(ctrl);
        pulse();

        ctrl = 1 << 29;  // rs1
        ctrl |= 0 << 28; // rs2
        set_ctrl(ctrl);
        set_rs1(1);
        set_rs2(2);
        pulse();

        set_issue(false);
        pulse();
        pulse();

        set_update(true);
        set_dest(1);
        set_value(0xcaac);
        pulse();

        set_update(false);
        pulse();

        set_issue(true);
        ctrl = 2 << 29;  // pc
        ctrl |= 1 << 28; // imm
        set_ctrl(ctrl);
        set_pc(0xdead);
        set_imm(0xbeef);
        pulse();

        set_issue(false);
        set_update(true);
        set_dest(2);
        set_value(0xacca);
        pulse();

        set_update(false);
        pulse();
        pulse();
        pulse();
        pulse();

        return 0;
}

}
