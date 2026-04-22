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

        // Register read port
        output  wire    [4:0]   rs1,
        output  wire    [4:0]   rs2,
        output  wire    [11:0]  csr,
        input   wire    [31:0]  rs1_val,
        input   wire    [31:0]  rs2_val,
        input   wire    [31:0]  csr_val,

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
        output  reg     [7:0]   funct3,
        output  reg     [127:0] funct7,

        // Data outputs
        output  reg     [31:0]  pc_o,
        output  reg     [31:0]  imm,
        output  reg     [4:0]   rd,
        output  reg     [31:0]  alu_in1,
        output  reg     [31:0]  alu_in2,
        output  reg     [31:0]  agu_in1,
        output  reg     [31:0]  agu_in2,
        output  reg     [31:0]  csru_in1,
        output  reg     [31:0]  csru_in2
);
 
wire is_r;
wire is_i;
wire is_s;
wire is_b;
wire is_u;
wire is_j;
wire [31:0] opcode;

assign opcode = rst ? {27'b0, 1'b1, 4'b0} : //ALUI
                        32'b1 << instr[6:2];

assign is_r = `ALUR;
assign is_i = `JALR | `LOAD | `ALUI | `SYSTEM;
assign is_s = `STORE;
assign is_b = `BRANCH;
assign is_u = `LUI | `AUIPC;
assign is_j = `JAL;

assign rs2 = (is_r | is_s | is_b) ?		instr[24:20] : 5'b0;
assign rs1 = (is_r | is_i | is_s | is_b) ?	instr[19:15] : 5'b0;
assign csr = `SYSTEM ? instr[31:20] : 12'b0;

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
                funct3 <= {7'b0, 1'b1}; // ADDI
                funct7 <= 0;
                pc_o <= 0;
                rd <= 0;
                imm <= 0;
                alu_in1 <= 0;
                alu_in2 <= 0;
                agu_in1 <= 0;
                agu_in2 <= 0;
                csru_in1 <= 0;
                csru_in2 <= 0;
        end else begin
                rd <= (is_r | is_i | is_u | is_j) ?	instr[11:7] : 5'b0;

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

                ebreak <=	`SYSTEM & funct3[0] & (instr[31:20] == 12'h1);
                ecall <=	`SYSTEM & funct3[0] & (instr[31:20] == 12'h0);
                mret <=		`SYSTEM & funct3[0] & (instr[31:20] == 12'h302);
                wfi <=		`SYSTEM & funct3[0] & (instr[31:20] == 12'h105);

                jump <= `JAL | `JALR;
                branch <= `BRANCH;
                store <= `STORE;
                load <= `LOAD;

                funct7 <= is_r ? (1 << instr[31:20]) : 0;
                funct3 <= (is_r | is_i | is_s | is_b) ?
                                (1 << instr[14:12]) : 0;


                alu_in1 <=	(`BRANCH | `ALUI | `ALUR) ?	rs1_val :
                                (`JAL | `JALR | `AUIPC) ?	pc_i :
                                                                32'h0;

                alu_in2 <=	(`ALUR | `BRANCH) ?		rs2_val :
                                (`LUI | `AUIPC | `ALUI) ?	imm :
                                (`JAL | `JALR) ?		32'h4 :
                                                                32'h0;

                agu_in1 <=	(`JALR | `STORE | `LOAD) ?	rs1_val :
                                (`JAL | `BRANCH) ?		pc_i:
                                                                32'h0;

                agu_in2 <=	(`JALR | `STORE | `LOAD | `JAL | `BRANCH) ?	imm :
                                                                                32'h0;

                csru_in1 <=	`SYSTEM ?	csr_val :
                                                32'b0;

                csru_in2 <=	`SYSTEM ? (	(funct3[1] | funct3[2] | funct3[3]) ?	rs1_val :
                                                (funct3[5] | funct3[6] | funct3[7]) ?	{27'b0, rs1} :
                                                                                        32'b0 ) :
                                                32'b0;
        end
end

endmodule
