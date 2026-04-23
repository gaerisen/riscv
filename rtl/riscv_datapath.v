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

module riscv_datapath
(
        input   wire            clk,
        input   wire            rst,

	// PC and instr input
	input	wire	[31:0]	pc,
	input	wire	[31:0]	instr,

	// Exception detection port
	output	wire		illegal_instruction,
	output	wire		breakpoint,
	output	wire		ecall,
	output	wire		mret,
	output	wire		wfi,

	// CSR read-write port
	output	wire	[11:0]	csr,
	input	wire	[31:0]	csr_value,
	output	wire	[31:0]	csr_wb,

	// Jump port
	output	wire		jump,
	output	wire	[31:0]	jump_target,

	// Memaccess port
	output	wire		is_mem_op,
	output	wire	[2:0]	mem_op,
	output	wire	[31:0]	mem_addr,
	input	wire	[31:0]	mem_load_data,
	output	wire	[31:0]	mem_store_data,

	// Register write port
	output	wire	[4:0]	rd,
	output	wire	[31:0]	irf_wb
);

wire	[7:0]	funct3;
wire	[127:0]	funct7;
wire	[31:0]	imm;
wire	[31:0]	alu_in1;
wire	[31:0]	alu_in2;
wire	[31:0]	agu_in1;
wire	[31:0]	agu_in2;
wire	[31:0]	csru_in1;
wire	[31:0]	csru_in2;

wire jump_dec_to_exe;
wire branch_dec_to_exe;
wire store_dec_to_exe;
wire load_dec_to_exe;

wire [31:0] pc_dec_to_exe;
wire [4:0] rd_dec_to_exe;

reg [31:0] irf [0:31];

wire alu_in1_is_rs1;
wire alu_in1_is_pc;
wire alu_in2_is_rs2;
wire alu_in2_is_imm;
               
wire agu_in1_is_rs1;
wire agu_in1_is_pc;
wire agu_in2_is_imm;
               
wire csru_in1_is_csr;
wire csru_in2_is_rs1;
wire csru_in2_is_imm;

wire [4:0] rs1;
wire [4:0] rs2;

riscv_decoder decoder0 (
        .clk(clk),
        .rst(rst),

        .pc_i(pc),
        .instr(instr),

        .illegal_instr(illegal_instruction),
        .ebreak(breakpoint),
        .ecall(ecall),
        .mret(mret),
        .wfi(wfi),

        .jump(jump_dec_to_exe),
        .branch(branch_dec_to_exe),
        .store(store_dec_to_exe),
        .load(load_dec_to_exe),

        .alu_in1_is_rs1(alu_in1_is_rs1),
        .alu_in1_is_pc(alu_in1_is_pc),
        .alu_in2_is_rs2(alu_in2_is_rs2),
        .alu_in2_is_imm(alu_in2_is_imm),

        .agu_in1_is_rs1(agu_in1_is_rs1),
        .agu_in1_is_pc(agu_in1_is_pc),
        .agu_in2_is_imm(agu_in2_is_imm),

        .csru_in1_is_csr(csru_in1_is_csr),
        .csru_in2_is_rs1(csru_in2_is_rs1),
        .csru_in2_is_imm(csru_in2_is_imm),

        .funct3(funct3),
        .funct7(funct7),

        .pc_o(pc_dec_to_exe),
        .imm(imm),
        .rs1(rs1),
        .rs2(rs2),
        .csr(csr),
        .rd(rd_dec_to_exe)
);

assign alu_in1 =        alu_in1_is_rs1 ? irf[rs1] :
                        alu_in1_is_pc ? pc_dec_to_exe : 0;
                
assign alu_in2 =        alu_in2_is_rs2 ? irf[rs2] :
                        alu_in2_is_imm ? imm : 
                        jump ? 32'h4 : 0;

assign agu_in1 =        agu_in1_is_rs1 ? irf[rs1] :
                        agu_in1_is_pc ? pc_dec_to_exe : 0;

assign agu_in2 =        agu_in2_is_imm ? imm : 0;

assign csru_in1 =       csru_in1_is_csr ? csr_value : 0;

assign csru_in2 =       csru_in2_is_rs1 ? irf[rs1] :
                        csru_in2_is_imm ? {27'b0, rs1} : 0;

// TODO: put ALU here :)

// Memory access logic
/*
assign mem_addr = (`STORE | `LOAD) ?	agu :
					32'b0;

assign mem_op[2] =	`STORE;

assign mem_op[1:0] =	(funct3[0] | funct3[4]) ?	2'b01 :
			(funct3[1] | funct3[5]) ?	2'b10 :
			funct3[2] ?			2'b11 :
							2'b00;

assign ld =	funct3[0] ?	{{24{mem_load_data[7]}}, mem_load_data[7:0]} :
		funct3[1] ?	{{16{mem_load_data[7]}}, mem_load_data[15:0]} :
		funct3[2] ?	mem_load_data :
		funct3[4] ?	{24'b0, mem_load_data[7:0]} :
		funct3[5] ?	{16'b0, mem_load_data[15:0]} :
				32'b0;

assign mem_store_data = `STORE ?	rs2_value :
					32'b0;

// Writeback logic

assign irf_wb =	`LOAD ?							ld :
		`SYSTEM ?						csr_value :
		(`LUI | `AUIPC | `JAL | `JALR | `ALUR | `ALUI) ?	alu :
									32'b0;

assign csr_wb =	csru;
*/

wire [4:0] rd_mem_to_wb = 0;

always @(posedge clk, posedge rst)
begin
	if (rst)
	begin
		for (integer i = 0; i < 32; i++)
		begin
			irf[i] <= 32'b0;
		end
	end else if (rd_mem_to_wb != 5'b0)
	begin
		irf[rd_mem_to_wb] <= irf_wb;
	end
end

endmodule
