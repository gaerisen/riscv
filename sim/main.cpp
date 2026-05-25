#include <verilated.h>
#include <iostream>
#include <iomanip>
#include <cstdlib>
#include <ctime>

#include "generator.hpp"
#include "decoder.hpp"

int i_ops[] = {
        0b11001, // jalr
        0b00000, // load
        0b00100, // alui
};

int u_ops[] = {
        0b01101, // lui
        0b00101, // auipc
};

int get_i_imm(int);
int get_s_imm(int);
int get_b_imm(int);
int get_u_imm(int);
int get_j_imm(int);

int main(int argc, char *argv[])
{
        auto ctx = std::make_shared<VerilatedContext>();

        ctx->traceEverOn(true);

        struct sim::generator r_gen;
        struct sim::generator i_gen;
        struct sim::generator s_gen;
        struct sim::generator b_gen;
        struct sim::generator u_gen;
        struct sim::generator j_gen;

        struct sim::decoder dut(ctx);

        srand(time(0));

        try {
                int idx;
                unsigned int instr;

                idx = gen.add_field(2, 0, 0b11);
                idx = gen.add_field(6, 2, opcodes, 11);

                for (int i = 0; i < 32; i++) {
                        instr = gen.generate();
                        instr |= (i << 7);
                        std::cout << std::hex << instr << std::endl;
                        dut.set_instr(instr);
                        dut.pulse();
                        std::cout << "\trs1: " << dut.get_rs1() << std::endl;
                        std::cout << "\trs2: " << dut.get_rs2() << std::endl;
                        std::cout << "\trd: " << dut.get_rd() << std::endl;
                        std::cout << "\timm: " << dut.get_imm() << std::endl;
                }
        } catch (const std::runtime_error& e) {
                std::cerr << "RUNTIME: " << e.what();
                return 1;
        } catch (const std::exception& e) {
                std::cerr << "EXCEPTION: " << e.what();
                return 1;
        } catch (...) {
                std::cerr << "Caught unexpected exception" << std::endl;
                return 1;
        }

        return 0;
}
