`define LUI opcode[13]
`define AUIPC opcode[5]
`define JAL opcode[27]
`define JALR opcode[25]
`define BRANCH opcode[24]
`define LOAD opcode[0]
`define STORE opcode[8]
`define ALUI opcode[4]
`define ALUR opcode[12]
`define FENCE opcode[15]
`define SYSTEM opcode[28]

module riscv_decoder (
        input   wire            clk,
        input   wire            rst,

        // Inputs from ifetch
        input   wire    [31:0]  pc_i,
        input   wire    [31:0]  instr,

        // Control outputs
        output  reg             illegal_instr,
        output  reg             ebreak,
        output  reg             ecall,
        output  reg             mret,
        output  reg             wfi,
        
        // Special instruction flags
        output  reg             jump,
        output  reg             branch,
        output  reg             store,
        output  reg             load,

        // ALU control outputs
        output  reg     alu_in1_is_rs1,
        output  reg     alu_in1_is_pc,
        output  reg     alu_in2_is_rs2,
        output  reg     alu_in2_is_imm,

        output  reg     agu_in1_is_rs1,
        output  reg     agu_in1_is_pc,
        output  reg     agu_in2_is_imm,

        output  reg     csru_in1_is_csr,
        output  reg     csru_in2_is_rs1,
        output  reg     csru_in2_is_imm,

        output  reg     [7:0]   funct3,
        output  reg     [127:0] funct7,

        // Data outputs
        output  reg     [31:0]  pc_o,
        output  reg     [31:0]  imm,
        output  reg     [4:0]   rs1,
        output  reg     [4:0]   rs2,
        output  reg     [11:0]  csr,
        output  reg     [4:0]   rd
);
 
wire is_r;
wire is_i;
wire is_s;
wire is_b;
wire is_u;
wire is_j;
wire is_zicsr;
wire [31:0] opcode;

assign opcode = rst ? {27'b0, 1'b1, 4'b0} : //ALUI
                        32'b1 << instr[6:2];

assign is_r = `ALUR;
assign is_i = `JALR | `LOAD | `ALUI | `SYSTEM;
assign is_s = `STORE;
assign is_b = `BRANCH;
assign is_u = `LUI | `AUIPC;
assign is_j = `JAL;

assign is_zicsr = `SYSTEM & (instr[13] | instr[12]);

always @(posedge clk) begin
        if (rst) begin
                illegal_instr <= 0;
                ebreak <= 0;
                ecall <= 0;
                mret <= 0;
                wfi <= 0;
                jump <= 0;
                branch <= 0;
                store <= 0;
                load <= 0;
                alu_in1_is_rs1 <= 0;
                alu_in1_is_pc <= 0;
                alu_in2_is_rs2 <= 0;
                alu_in2_is_imm <= 0;
                agu_in1_is_rs1 <= 0;
                agu_in1_is_pc <= 0;
                agu_in2_is_imm <= 0;
                csru_in1_is_csr <= 0;
                csru_in2_is_rs1 <= 0;
                csru_in2_is_imm <= 0;
                funct3 <= {7'b0, 1'b1}; // ADDI
                funct7 <= 0;
                pc_o <= 0;
                rd <= 0;
                imm <= 0;
        end else begin
                pc_o <= pc_i;

                rd <= (is_r | is_i | is_u | is_j) ?	instr[11:7] : 5'b0;
                rs1 <= (is_r | is_i | is_s | is_b) ?	instr[19:15] : 5'b0;
                rs2 <= (is_r | is_s | is_b) ?	        instr[24:20] : 5'b0;
                csr <= `SYSTEM ? instr[31:20] : 12'b0;

                alu_in1_is_rs1 <= `BRANCH | `ALUI | `ALUR;
                alu_in1_is_pc <= `JAL | `JALR | `AUIPC;
                alu_in2_is_rs2 <= `ALUR | `BRANCH;
                alu_in2_is_imm <= `LUI | `AUIPC | `ALUI;
                agu_in1_is_rs1 <= `JALR | `STORE | `LOAD;
                agu_in1_is_pc <= `JAL | `BRANCH;
                agu_in2_is_imm <= `JALR | `STORE | `LOAD | `JAL | `BRANCH;
                csru_in1_is_csr <= is_zicsr;
                csru_in2_is_rs1 <= is_zicsr & ~instr[14];
                csru_in2_is_imm <= is_zicsr & instr[14];

                imm[31] <=	instr[31];
                imm[30:20] <=	is_u ?	instr[30:20] :
                                        {{11{instr[31]}}};
                imm[19:12] <=	(is_u | is_j) ?	instr[19:12] :
                                                {{8{instr[31]}}};
                imm[11] <=	is_b ?	instr[7] :
                                        is_u ?	1'b0 :
                                        is_j ?	instr[20] :
                                                instr[31];
                imm[10:5] <=	is_u ?	6'b0 :
                                        instr[30:25];
                imm[4:1] <=	(is_i | is_j) ?	instr[24:21] :
                                        (is_s | is_b) ?	instr[11:8] :
                                        4'b0;
                imm[0] <=		is_i ?	instr[20] :
                                        is_s ?	instr[7] :
                                                1'b0;

                illegal_instr <=	~(instr[1] & instr[0]) |
                                        ~(	`LUI | `AUIPC | `JAL | `JALR |
                                                `BRANCH | `LOAD | `STORE | `ALUI |
                                                `ALUR | `FENCE | `SYSTEM );

                ebreak <=	`SYSTEM & (instr[14:12] == 0) & (instr[31:20] == 12'h1);
                ecall <=	`SYSTEM & (instr[14:12] == 0) & (instr[31:20] == 12'h0);
                mret <=		`SYSTEM & (instr[14:12] == 0) & (instr[31:20] == 12'h302);
                wfi <=		`SYSTEM & (instr[14:12] == 0) & (instr[31:20] == 12'h105);

                jump <= `JAL | `JALR;
                branch <= `BRANCH;
                store <= `STORE;
                load <= `LOAD;

                funct7 <= is_r ? (1 << instr[31:20]) : 0;
                funct3 <= (is_r | is_i | is_s | is_b) ?
                                (1 << instr[14:12]) : 
                        (is_j | is_u) ? 1 : 0;


        end
end

endmodule
