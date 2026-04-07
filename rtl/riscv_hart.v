module riscv_hart
(
	input	wire		clk,
	input	wire		rst,

	output	wire		icache_addr_valid,
	output	wire	[31:0]	icache_addr,
	input	wire		icache_data_ready,
	input	wire	[31:0]	icache_data,

	output	wire	[2:0]	dcache_mem_op,
	output	wire		dcache_addr_valid,
	output	wire	[31:0]	dcache_addr,
	input	wire		dcache_read_data_ready,
	input	wire	[31:0]	dcache_read_data,
	output	wire		dcache_write_data_valid,
	output	wire	[31:0]	dcache_write_data,

	input	wire		hardware_irq,
	input	wire		timer_irq
);

integer i;

wire		illegal_instruction;
wire		breakpoint;
wire		ecall;
wire		trap;
wire		mret;
wire		wfi;
wire	[31:0]	trap_target;
wire	[31:0]	mret_target;
wire	[31:0]	nextpc;
wire	[4:0]	rs1;
wire	[4:0]	rs2;
wire	[11:0]	csr;
wire	[4095:0]	csr_;
wire	[31:0]	csr_value;
wire		jump;
wire	[31:0]	jump_target;
wire	[4:0]	rd;
wire	[31:0]	csr_wb;
wire	[31:0]	irf_wb;

// Main operation registers

reg	[31:0]	pc;	// Datapath PC
reg	[31:0]	pc_;	// Control PC
reg	[31:0]	instr;
reg	[31:0]	irf	[0:31];


// Initialize regs

initial
begin
	pc = -4;
	pc_ = -4;
	instr = 32'h13;

	for (i = 0; i < 32; i++)
	begin
		irf[i] = 0;
	end
end

riscv_control control
(
	.clk(clk),
	.rst(rst),

	// CSR read/write port
	.csr(csr),
	.csr_(csr_),
	.csr_value(csr_value),
	.csr_wb(csr_wb),

	// Memory access monitoring port
	.pc(pc),
	.pc_(pc_),
	.imem_data_ready(icache_data_ready),
	.dmem_op(dcache_mem_op),
	.addr(dcache_addr),

	// Inline event port
	.illegal_instruction(illegal_instruction),
	.breakpoint(breakpoint),
	.ecall(ecall),
	.mret(mret),
	.wfi(wfi),

	// Interrupt port
	.hardware_irq(hardware_irq),
	.timer_irq(timer_irq),

	// Trap port
	.trap(trap),
	.trap_target(trap_target),
	.mret_target(mret_target)
);


// Fetch logic

assign nextpc =	rst ?				0 :
		trap ?				trap_target :
		wfi ?				pc :
		mret ?				mret_target :
		jump ?				jump_target :
						pc + 4;

assign icache_addr_valid = 1;
assign icache_addr = nextpc;

always @(posedge clk, posedge rst)
begin
	if (rst)
	begin
		pc <= -4;
		pc_ <= -4;
		instr <= 32'h13;
	end
	else if (icache_data_ready & (dcache_addr_valid ? dcache_read_data_ready : 1))
	begin
		pc <= nextpc;
		pc_ <= nextpc;
		instr <= icache_data;
	end
	else
		pc_ <= nextpc;
end


riscv_datapath datapath
(
	.clk(clk),

	// instruction/pc input
	.pc(pc),
	.instr(instr),

	// exception detection port
	.illegal_instruction(illegal_instruction),
	.breakpoint(breakpoint),
	.ecall(ecall),
	.mret(mret),
	.wfi(wfi),

	// irf read port
	.rs1(rs1),
	.rs2(rs2),
	.rs1_value(irf[rs1]),
	.rs2_value(irf[rs2]),

	// csr read/write port
	.csr(csr),
	.csr_(csr_),
	.csr_value(csr_value),
	.csr_wb(csr_wb),

	// jump port
	.jump(jump),
	.jump_target(jump_target),

	// memory access port 
	.is_mem_op(dcache_addr_valid),
	.mem_op(dcache_mem_op),
	.mem_addr(dcache_addr),
	.mem_load_data(dcache_read_data),
	.mem_store_data(dcache_write_data),

	// irf writeback port 
	.rd(rd),
	.irf_wb(irf_wb)
);

// Writeback

always @(posedge clk, posedge rst)
begin
	if (rst)
	begin
		for (i = 0; i < 32; i++)
		begin
			irf[i] <= 32'b0;
		end
	end else if ((rd != 5'b0) & icache_data_ready)
	begin
		irf[rd] <= irf_wb;
	end
end

endmodule
