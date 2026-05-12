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
        } funct7_e;

        /*====================================================================*/
        /*              SOURCE ENUMS                                          */
        /*====================================================================*/
        typedef enum logic [1:0] {
                RS1,
                PC,
                ZERO
        } alu_src1_e;

        typedef enum logic {
                RS2,
                IMM
        } alu_src2_e;

        typedef enum logic [1:0] {
                ALU,
                MEM,
                PC4
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
                opcode_e opcode;

                alu_funct3_e alu_op;
                alu_funct7_e alu_alt;
                alu_src1_e alu_src1;
                alu_src2_e alu_src2;

                logic branch;
                branch_funct3_e branch_op;

                logic jump;

                logic load;
                load_funct3_e load_op;

                logic store;
                store_funct3_e store_op;

                logic wb;
                wb_src_e wb_src;
        } ctrl_t;

endpackage: rv32
