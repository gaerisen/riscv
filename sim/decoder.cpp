#include "decoder.hpp"
#include "generator.hpp"
#include <iostream>
#include <iomanip>

namespace sim
{

decoder::decoder(std::shared_ptr<VerilatedContext> ctx):
        device(ctx)
{
        dut->stall = 0;
        dut->flush = 0;
        dut->instr_i = 0;
}

decoder::~decoder()
{
        dut->final();
}

void decoder::stall(int n)
{
        dut->stall = 1;

        for (int i = 0; i < n; i++) {
                pulse();
        }

        dut->stall = 0;

        return;
}

void decoder::flush(int n)
{
        dut->flush = 1;

        for (int i = 0; i < n; i++) {
                pulse();
        }

        dut->flush = 0;

        return;
}

} // namespace sim
  //
int i_ops[] = {
        0b11001, // jalr
        0b00000, // load
        0b00100, // alui
};

int u_ops[] = {
        0b01101, // lui
        0b00101, // auipc
};

int get_i_imm(int i)
{
        int imm = i >> 20;

        return imm;
}

int get_u_imm(int i)
{
        int mask = -1 << 12;
        return i & mask;
}

int get_s_imm(int i)
{
        int sign_sel = 1 << 31;
        int sign = (sign_sel & i) >> (31-12);

        int imm_lo_sel = 31;
        int imm_lo = (i >> 7) & imm_lo_sel;

        int imm_hi_sel = 127 << 5;
        int imm_hi = (i >> (25-5)) & imm_hi_sel;

        int imm = imm_hi | imm_lo | sign;

        return imm;
}

int get_b_imm(int i)
{
        int sign_sel = 1 << 31;
        int sign = (sign_sel & i) >> (31-12);

        int imm10_5_sel = 63 << 25;
        int imm4_1_sel = 15 << 8;
        int imm11_sel = 1 << 7;

        int imm10_5 = (imm10_5_sel & i) >> (25-5);
        int imm4_1 = (imm4_1_sel & i) >> (8-1);
        int imm11 = (imm11_sel & i) << (11-7);

        int imm = sign | imm11 | imm10_5 | imm4_1;

        return imm;
}

int get_j_imm(int i)
{
        int sign_sel = 1 << 31;
        int sign = (sign_sel & i) >> (31 - 20);

        int imm10_1_sel = 1023 << 21;
        int imm11_sel = 1 << 20;
        int imm19_12_sel = 255 << 12;

        int imm10_1 = (imm10_1_sel & i) >> (21-1);
        int imm11 = (imm11_sel & i) >> (20-11);
        int imm19_12 = (imm19_12_sel & i);

        int imm = sign | imm19_12 | imm11 | imm10_1;
        return imm;
}

void run_tests(struct sim::decoder& dut)
{
        struct sim::generator r_gen;
        struct sim::generator i_gen;
        struct sim::generator s_gen;
        struct sim::generator b_gen;
        struct sim::generator u_gen;
        struct sim::generator j_gen;

        unsigned int instr;

        unsigned int rs1_mask = 31 << 15;
        unsigned int rs2_mask = 31 << 20;
        unsigned int rd_mask = 31 << 7;

        r_gen.add_field(2, 0, 0b11);
        r_gen.add_field(6, 2, 0b01100);
        r_gen.add_field(11, 7, 0, 31);
        r_gen.add_field(19, 15, 0, 31);
        r_gen.add_field(24, 20, 0, 31);

        dut.reset(5);

        std::cout << "=== R-type ===" << std::endl;

        for (int i = 0; i < 32; i++) {
                instr = r_gen.generate();

                std::cout << std::hex << instr << std::endl;

                dut.set_instr(instr);
                dut.pulse();

                if ((rs1_mask & instr) >> 15 != dut.get_rs1()) {
                        std::cout << "\trs1: " << ((rs1_mask & instr) >> 15);
                        std::cout << "\t" << dut.get_rs1() << std::endl;
                }

                if ((rs2_mask & instr) >> 20 != dut.get_rs2()) {
                        std::cout << "\trs2: " << ((rs2_mask & instr) >> 20);
                        std::cout << "\t" << dut.get_rs2() << std::endl;
                }

                if ((rd_mask & instr) >> 7 != dut.get_rd()) {
                        std::cout << "\trd: " << ((rd_mask & instr) >> 7);
                        std::cout << "\t" << dut.get_rd() << std::endl;
                }
        }

        i_gen.add_field(2, 0, 0b11);
        i_gen.add_field(6, 2, i_ops, 3);
        i_gen.add_field(11, 7, 0, 31);
        i_gen.add_field(19, 15, 0, 31);
        i_gen.add_field(31, 20, 0, 4095);

        dut.reset(5);

        std::cout << "\n=== I-type ===" << std::endl;

        for (int i = 0; i < 32; i++) {
                instr = i_gen.generate();

                std::cout << std::hex << instr << std::endl;

                dut.set_instr(instr);
                dut.pulse();

                if ((rs1_mask & instr) >> 15 != dut.get_rs1()) {
                        std::cout << "\trs1: " << ((rs1_mask & instr) >> 15);
                        std::cout << "\t" << dut.get_rs1() << std::endl;
                }

                if ((rd_mask & instr) >> 7 != dut.get_rd()) {
                        std::cout << "\trd: " << ((rd_mask & instr) >> 7);
                        std::cout << "\t" << dut.get_rd() << std::endl;
                }

                if (get_i_imm(instr) != dut.get_imm()) {
                        std::cout << "\timm: " << get_i_imm(instr);
                        std::cout << "\t" << dut.get_imm() << std::endl;
                }
        }

        s_gen.add_field(2, 0, 0b11);
        s_gen.add_field(6, 2, 0b01000);
        s_gen.add_field(11, 7, 0, 31);
        s_gen.add_field(19, 15, 0, 31);
        s_gen.add_field(24, 20, 0, 31);
        s_gen.add_field(31, 25, 0, 127);

        dut.reset(5);
        std::cout << "\n=== S-type ===" << std::endl;

        for (int i = 0; i < 32; i++) {
                instr = s_gen.generate();

                std::cout << std::hex << instr << std::endl;

                dut.set_instr(instr);
                dut.pulse();

                if ((rs1_mask & instr) >> 15 != dut.get_rs1()) {
                        std::cout << "\trs1: " << ((rs1_mask & instr) >> 15);
                        std::cout << "\t" << dut.get_rs1() << std::endl;
                }

                if ((rs2_mask & instr) >> 20 != dut.get_rs2()) {
                        std::cout << "\trs2: " << ((rs2_mask & instr) >> 20);
                        std::cout << "\t" << dut.get_rs2() << std::endl;
                }

                if (get_s_imm(instr) != dut.get_imm()) {
                        std::cout << "\timm: " << get_s_imm(instr);
                        std::cout << "\t" << dut.get_imm() << std::endl;
                }
        }


        u_gen.add_field(2, 0, 0b11);
        u_gen.add_field(6, 2, u_ops, 2);
        u_gen.add_field(11, 7, 0, 31);
        u_gen.add_field(31, 12, 0, 1048575);

        dut.reset(5);
        std::cout << "\n=== U-type ===" << std::endl;

        for (int i = 0; i < 32; i++) {
                instr = u_gen.generate();

                std::cout << std::hex << instr << std::endl;

                dut.set_instr(instr);
                dut.pulse();

                if ((rd_mask & instr) >> 7 != dut.get_rd()) {
                        std::cout << "\trd: " << ((rd_mask & instr) >> 7);
                        std::cout << "\t" << dut.get_rd() << std::endl;
                }

                if (get_u_imm(instr) != dut.get_imm()) {
                        std::cout << "\timm: " << get_u_imm(instr);
                        std::cout << "\t" << dut.get_imm() << std::endl;
                }
        }

        b_gen.add_field(2, 0, 0b11);
        b_gen.add_field(6, 2, 0b11000);
        b_gen.add_field(11, 7, 0, 31);
        b_gen.add_field(19, 15, 0, 31);
        b_gen.add_field(24, 20, 0, 31);
        b_gen.add_field(31, 25, 0, 127);

        dut.reset(5);
        std::cout << "\n=== B-type ===" << std::endl;

        for (int i = 0; i < 32; i++) {
                instr = b_gen.generate();

                std::cout << std::hex << instr << std::endl;

                dut.set_instr(instr);
                dut.pulse();

                if ((rs1_mask & instr) >> 15 != dut.get_rs1()) {
                        std::cout << "\trs1: " << ((rs1_mask & instr) >> 15);
                        std::cout << "\t" << dut.get_rs1() << std::endl;
                }

                if ((rs2_mask & instr) >> 20 != dut.get_rs2()) {
                        std::cout << "\trs2: " << ((rs2_mask & instr) >> 20);
                        std::cout << "\t" << dut.get_rs2() << std::endl;
                }

                if (get_b_imm(instr) != dut.get_imm()) {
                        std::cout << "\timm: " << get_b_imm(instr);
                        std::cout << "\t" << dut.get_imm() << std::endl;
                }
        }

        j_gen.add_field(2, 0, 0b11);
        j_gen.add_field(6, 2, 0b11011);
        j_gen.add_field(11, 7, 0, 31);
        j_gen.add_field(31, 12, 0, 1048575);

        dut.reset(5);
        std::cout << "\n=== J-type ===" << std::endl;

        for (int i = 0; i < 32; i++) {
                instr = j_gen.generate();

                std::cout << std::hex << instr << std::endl;

                dut.set_instr(instr);
                dut.pulse();

                if ((rd_mask & instr) >> 7 != dut.get_rd()) {
                        std::cout << "\trd: " << ((rd_mask & instr) >> 7);
                        std::cout << "\t" << dut.get_rd() << std::endl;
                }

                if (get_j_imm(instr) != dut.get_imm()) {
                        std::cout << "\timm: " << get_j_imm(instr);
                        std::cout << "\t" << dut.get_imm() << std::endl;
                }
        }
        
        return;
}
