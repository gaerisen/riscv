`timescale 1ps / 1ps
package rv32;

        /*====================================================================*/
        /*              ENUM DECLARATIONS FOR INSTR FIELDS                    */
        /*====================================================================*/
        typedef enum logic [6:0] {
                LUI     = 7'b01101_11,
                AUIPC   = 7'b00101_11,
                JAL     = 7'b11011_11,
                JALR    = 7'b11001_11,
                BRANCH  = 7'b11000_11,
                LOAD    = 7'b00000_11,
                STORE   = 7'b01000_11,
                ALUI    = 7'b00100_11,
                ALUR    = 7'b01100_11,
                FENCE   = 7'b00011_11,
                SYSTEM  = 7'b11100_11
        } opcode_e;

        typedef enum logic [2:0] {
                BEQ     = 3'b000,       BGE     = 3'b101,
                BNE     = 3'b001,       BLTU    = 3'b110,
                BLT     = 3'b100,       BGEU    = 3'b111
        } branch_funct3_e;

        typedef enum logic [2:0] {
                LB    = 3'b000,         LBU     = 3'b100,
                LH    = 3'b001,         LHU     = 3'b101,
                LW    = 3'b010
        } load_funct3_e;

        typedef enum logic [2:0] {
                SB    = 3'b000,
                SH    = 3'b001,
                SW    = 3'b010
        } store_funct3_e;
                
        typedef enum logic [2:0] {
                ADDSUB  = 3'b000,       XOR     = 3'b100,
                SLL     = 3'b001,       SR      = 3'b101,
                SLT     = 3'b010,       OR      = 3'b110,
                SLTU    = 3'b011,       AND     = 3'b111
        } alu_funct3_e;

        typedef enum logic [6:0] {
                ALT     = 7'b01_00000,
                NORM    = 7'b00_00000
        } alu_funct7_e;



        typedef enum logic [1:0] {
                CSRRW   = 2'b01,
                CSRRS   = 2'b10,
                CSRRC   = 2'b11
        } csr_funct2_e;

        typedef enum logic {
                NRS1    = 0,
                UIMM    = 1
        } csr_src_e;

        typedef enum logic [3:0] {
                INST_ADDR_MISAL = 0,
                INST_ACC_FAULT = 1,
                ILLEGAL = 2,
                EBREAK = 3,
                LOAD_ADDR_MISAL = 4,
                LOAD_ACC_FAULT = 5,
                STORE_ADDR_MISAL = 6,
                STORE_ACC_FAULT = 7,
                // ECALLs have different cause codes for M-S-U modes, but the
                // decoder doesn't know current priv, so I'm collapsing them
                // into one. Whether this changes in the future depends on how
                // messy handling it in the CSRF gets
                ECALL = 11
        } trap_cause_e;

        /*====================================================================*/
        /*          ALU SOURCE ENUMS                                          */
        /*====================================================================*/
        typedef enum logic [1:0] {
                ZERO    = 2'b00,
                RS1     = 2'b01,
                PC      = 2'b10
        } alu_src1_e;

        typedef enum logic {
                RS2     = 1'b0,
                IMM     = 1'b1
        } alu_src2_e;

        typedef enum logic [1:0] {
                WB_ALU     = 2'b00,
                WB_MEM     = 2'b01,
                WB_PC4     = 2'b10,
                WB_CSR     = 2'b11
        } wb_src_e;

        /*====================================================================*/
        /*              ENCODED INSTRUCTION TYPEDEF                           */
        /*====================================================================*/
        typedef union packed {
                logic [31:0] raw;

                struct packed {
                        logic [6:0] funct7;
                        logic [4:0] rs2;
                        logic [4:0] rs1;
                        logic [2:0] funct3;
                        logic [4:0] rd;
                        logic [6:0] opcode;
                } r;

                struct packed {
                        logic [11:0] imm11_0;
                        logic [4:0] rs1;
                        logic [2:0] funct3;
                        logic [4:0] rd;
                        logic [6:0] opcode;
                } i;

                struct packed {
                        logic [6:0] imm11_5;
                        logic [4:0] rs2;
                        logic [4:0] rs1;
                        logic [2:0] funct3;
                        logic [4:0] imm4_0;
                        logic [6:0] opcode;
                } s;

                struct packed {
                        logic imm12;
                        logic [5:0] imm10_5;
                        logic [4:0] rs2;
                        logic [4:0] rs1;
                        logic [2:0] funct3;
                        logic [3:0] imm4_1;
                        logic imm11;
                        logic [6:0] opcode;
                } b;

                struct packed {
                        logic [19:0] imm31_12;
                        logic [4:0] rd;
                        logic [6:0] opcode;
                } u;

                struct packed {
                        logic imm20;
                        logic [9:0] imm10_1;
                        logic imm11;
                        logic [7:0] imm19_12;
                        logic [4:0] rd;
                        logic [6:0] opcode;
                } j;
        } instr_t;

        /*====================================================================*/
        /*              DECODED INSTRUCTION TYPEDEF                           */
        /*====================================================================*/
        typedef struct packed {
                // Instruction type signals
                logic branch;
                logic jump;
                logic load;
                logic store;
                logic exception;
                logic trapret;
                logic wfi;

                // RF write enables
                logic irf_we;
                logic csr_we;

                // Source enums
                alu_src1_e alu_src1;
                alu_src2_e alu_src2;
                wb_src_e wb_src;
                csr_src_e csr_src;

                // Operation enums
                alu_funct3_e alu_op;
                alu_funct7_e alu_alt;
                branch_funct3_e branch_op;
                load_funct3_e load_op;
                store_funct3_e store_op;
                csr_funct2_e csr_op;

                trap_cause_e trap_cause;
        } ctrl_t;


        /*====================================================================*/
        /*              TOMASULO BUFFER ENTRY TYPES                           */
        /*====================================================================*/
        typedef struct packed {
                logic [31:0] pc;
                ctrl_t ctrl_word;
                logic [31:0] in1;
                logic [31:0] in2;

        } rs_entry_t;

        typedef struct packed {
                ctrl_t ctrl_word;
                logic [31:0] dest;
                logic [31:0] value;
                logic [31:0] pc;
                logic ready;
        } rob_entry_t;


endpackage: rv32
