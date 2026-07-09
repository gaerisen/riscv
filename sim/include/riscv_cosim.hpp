/** riscv_cosim.hpp
 *
 * Copyright 2026 Garrison Taylor
 *
 * A fully-featured RV32UI simulator designed for seamless integration as a
 * cosimulator in a verification testbench.
 */

#ifndef RISCV_COSIM_HPP
#define RISCV_COSIM_HPP

#include <cstdint>

#ifndef INSTR_FIELD_MACROS
#define INSTR_FIELD_MACROS
#define opcode(x) (x & 0b1111111)
#define rd(x) ((x & (0b11111 << 7)) >> 7)
#define f3(x) ((x & (0b111 << 12)) >> 12)
#define rs1(x) ((x & (0b11111 << 15)) >> 15)
#define rs2(x) ((x & (0b11111 << 20)) >> 20)
#define f7(x) ((x & (0b1111111 << 25)) >> 25)
#endif

typedef enum {
        LUI     = 0x37,
        AUIPC   = 0x17,
        JAL     = 0x6f,
        JALR    = 0x67,
        BRANCH  = 0x63,
        LOAD    = 0x03,
        STORE   = 0x23,
        ALUI    = 0x13,
        ALUR    = 0x33,
        FENCE   = 0x0f,
        SYSTEM  = 0x73
} opcode_e;

typedef enum {
        BEQ = 0,	BGE = 5,
        BNE = 1,	BLTU = 6,
        BLT = 4,	BGEU = 7
} branch_f3_e;

typedef enum {
        LB = 0, LBU = 4,
        LH = 1,	LHU = 5,
        LW = 2
} load_f3_e;

typedef enum {
        SB = 0,
        SH = 1,
        SW = 2
} store_f3_e;

typedef enum {
        ADDSUB = 0,     XOR = 4,
        SLL = 1,        SR = 5,
        SLT = 2,        OR = 6,
        SLTU = 3,       AND = 7
} alu_f3_e;

typedef enum {
        REG_REG, REG_IMM, ZERO_IMM, PC_IMM
} alu_src_e;

typedef enum {
        WB_ALU, WB_MEM, WB_PC4
} wb_src_e;

typedef union {
        struct {
                uint8_t funct7;
                uint8_t rs2;
                uint8_t rs1;
                uint8_t funct3;
                uint8_t rd;
                uint8_t opcode;
        } r;
        struct {
                uint8_t imm11_5;
                uint8_t imm4_0;
                uint8_t rs1;
                uint8_t funct3;
                uint8_t rd;
                uint8_t opcode;
        } i;
        struct {
                uint8_t imm11_5;
                uint8_t rs2;
                uint8_t rs1;
                uint8_t funct3;
                uint8_t imm4_0;
                uint8_t opcode;
        } s;
        struct {
                uint8_t imm12_and_10_5;
                uint8_t rs2;
                uint8_t rs1;
                uint8_t funct3;
                uint8_t imm4_1_and_11;
                uint8_t opcode;
        } b;
        struct {
                uint8_t imm31_25;
                uint8_t imm24_20;
                uint8_t imm19_15;
                uint8_t imm14_12;
                uint8_t rd;
                uint8_t opcode;
        } u;
        struct {
                uint8_t imm20_and_10_5;
                uint8_t imm4_1_and_11;
                uint8_t imm19_15;
                uint8_t imm14_12;
                uint8_t rd;
                uint8_t opcode;
        } j;
} instr_t;

typedef struct {
        alu_f3_e op;
        bool alt;
        uint32_t in1;
        uint32_t in2;
} ctrl_word_t;

namespace sim
{

struct rv32ui 
{
public:
        rv32ui();
        ~rv32ui();

        void reset();
        void eval(uint32_t instr);

        uint32_t get_nextpc() { return nextpc; }
        uint32_t get_pc() { return pc; }
        uint32_t get_result() { return result; }
        uint32_t get_dest() { return dest; }

private:
        uint32_t nextpc;
        uint32_t pc;
        uint32_t result;
        uint32_t dest;
        uint32_t irf[32];
};

} // namespace sim

#endif // RISCV_COSIM_HPP
