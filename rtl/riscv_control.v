module riscv_control
(
	input	wire		clk,
	input	wire		rst,

	// CSR read/write port
	input	wire	[11:0]	csr,
	input	wire	[4095:0]	csr_,
	output	wire	[31:0]	csr_value,
	input	wire	[31:0]	csr_wb,

	// Memory access port
	input	wire	[31:0]	pc_,
	input	wire	[31:0]	pc,
	input	wire		imem_data_ready,
	input	wire	[2:0]	dmem_op,
	input	wire	[31:0]	addr,

	// Inline event port
	input	wire		illegal_instruction,
	input	wire		breakpoint,
	input	wire		ecall,
	input	wire		mret,
	input	wire		wfi,

	// Interrupt port
	input	wire		hardware_irq,
	input	wire		timer_irq,

	// Trap port
	output	wire		trap,
	output	wire	[31:0]	trap_target,
	output	wire	[31:0]	mret_target
);

integer i;

wire	instr_address_misaligned;
wire	instr_access_fault;
wire	load_address_misaligned;
wire	load_access_fault;
wire	store_address_misaligned;
wire	store_access_fault;
wire	exception_trap;
wire	[3:0]	exception_cause;
wire	interrupt_trap;
wire	[3:0]	interrupt_cause;
wire	[31:0]	interrupt_tvec;
wire	[63:0]	mstatus_;

// Control & Status registers

reg	[63:0]	mstatus;
reg	[31:0]	mtvec;
reg	[31:0]	mip;
reg	[31:0]	mie;
reg	[63:0]	mcycle;
reg	[63:0]	minstret;
reg	[63:0]	mhpmcounter	[3:31];
reg	[31:0]	mhpmevent	[3:31];
reg	[31:0]	mcountinhibit;
reg	[31:0]	mscratch;
reg	[31:0]	mepc;
reg	[31:0]	mcause;

initial
begin
	mstatus = 64'b0;
	mtvec = 32'b0;
	mip = 32'b0;
	mie = 32'b0;
	mcycle = 64'b0;
	minstret = 64'b0;
	mcountinhibit = 32'b0;
	mscratch = 32'b0;
	mepc = 32'b0;
	mcause = 32'b0;

	for (i = 3; i < 32; i++)
	begin
		mhpmcounter[i] = 64'b0;
		mhpmevent[i] = 32'b0;
	end
end

// Memory access exception detection

assign instr_address_misaligned = (pc_[1] | pc_[0]);

assign instr_access_fault = (pc_[31:15] != 0);

assign load_address_misaligned = ~dmem_op[2] & (	((dmem_op[1:0] == 2) & addr[0]) |
							((dmem_op[1:0] == 3) & (addr[1] | addr[0])));

assign load_access_fault = ~dmem_op[2] & (addr > 32'hc00c);

assign store_address_misaligned = dmem_op[2] & (	((dmem_op[1:0] == 2) & addr[0]) |
							((dmem_op[1:0] == 3) & (addr[1] | addr[0])));

assign store_access_fault = dmem_op[2] & ((addr < 32'h8004) | (addr > 32'hc00c));

// Exception trap logic

assign exception_trap =	instr_address_misaligned |
			instr_access_fault |
			illegal_instruction |
			breakpoint |
			load_address_misaligned |
			load_access_fault |
			store_address_misaligned |
			store_access_fault |
			ecall;

assign exception_cause =	instr_address_misaligned ?	4'd0 :
				instr_access_fault ?		4'd1 :
				illegal_instruction ?		4'd2 :
				breakpoint ?			4'd3 :
				load_address_misaligned ?	4'd4 :
				load_access_fault ?		4'd5 :
				store_address_misaligned ?	4'd6 :
				store_access_fault ?		4'd7 :
				ecall ?				4'd11 :
								4'd0;

// Interrupt trap logic

assign interrupt_trap =	mstatus[3] & (	(mie[11] & mip[11]) |
					(mie[7] & mip[7]) |
					(mie[3] & mip[3]));

assign interrupt_cause =	(mie[11] & mip[11]) ?	4'd11 :
				(mie[7] & mip[7]) ?	4'd7 :
				(mie[3] & mip[3]) ?	4'd3 :
							4'd0;

assign interrupt_tvec =	{mtvec[31:2] + (mtvec[0] ? {26'b0, interrupt_cause} : 30'b0), 2'b0};

// Unify exception and interrupt traps

assign trap = exception_trap | interrupt_trap;

assign trap_target =	interrupt_trap ?	interrupt_tvec :
			exception_trap ?	{mtvec[31:2], 2'b0} :
						32'b0;

assign mret_target =	mepc;

// CSR read

assign mstatus_ =	{56'b0, mstatus[7], 3'b0, mstatus[3], 3'b0};

assign csr_value =	csr_[12'h300] ?			mstatus_[31:0] :
			csr_[12'h301] ?			32'h40000100 :
			csr_[12'h304] ?			mie :
			csr_[12'h305] ?			mtvec :
			csr_[12'h310] ?			mstatus_[63:32] :
			csr_[12'h320] ?			mcountinhibit :
			csr_[12'h340] ?			mscratch :
			csr_[12'h341] ?			mepc :
			csr_[12'h342] ?			mcause :
			csr_[12'h344] ?			mip :
			csr_[12'hb00] ?			mcycle[31:0] :
			csr_[12'hb02] ?			minstret[31:0] :
			csr_[12'hb80] ?			mcycle[63:32] :
			csr_[12'hb82] ?			minstret[63:32] :
			32'h0;

always @(posedge clk, posedge rst)
begin
	if (rst)
	begin
		for (i = 3; i < 32; i++)
		begin
			mhpmcounter[i] <= 64'b0;
			mhpmevent[i] <= 32'b0;
		end

		mstatus <= 0;
		mtvec <= 0;
		mip <= 0;
		mie <= 0;
		mcycle <= 0;
		minstret <= 0;
		mcountinhibit <= 0;
		mscratch <= 0;
		mepc <= 0;
		mcause <= 0;
	end else if (imem_data_ready)
	begin
		// Interrupt queue handling

		if (mip[11] & interrupt_trap & (interrupt_cause == 11))
		begin
			mip[11] <= 0;
		end
		else if (mip[7] & interrupt_trap & (interrupt_cause == 8))
		begin
			mip[7] <= 0;
		end
		else if (hardware_irq)
		begin
			mip[11] <= 1;
		end
		else if (timer_irq)
		begin
			mip[7] <= 1;
		end
		else if (csr_[12'h344])
		begin
			mip <= csr_wb;
		end


		// Trap Handling

		if (exception_trap)
		begin
			mcause <= {28'b0, exception_cause};		// Forward exception type to mcause
			mepc <= pc;					// Save exception PC
			mstatus[7] <= mstatus[3];			// Update mpie from mie
			mstatus[3] <= 0;				// Disable interrupts
		end
		else if (interrupt_trap)
		begin
			mcause <= {1'b0, 27'b0, interrupt_cause};	
			mepc <= pc;
			mstatus[7] <= mstatus[3];
			mstatus[3] <= 0;
		end
		else if (mret)
		begin
			mstatus[3] <= mstatus[7];			// Update mie from mpie
			mstatus[7] <= 1;				// set mpie
		end
		else if (csr_[12'h342])
		begin
			mcause <= csr_wb;
		end
		else if (csr_[12'h300])
		begin
			mstatus[31:0] <= csr_wb;
		end
		else if (csr_[12'h341])
		begin
			mepc <= csr_wb;
		end


		// Cycle counter

		if (csr_[12'hb00])
		begin
			mcycle[31:0] <= csr_wb;
		end
		else if (csr_[12'hb80])
		begin
			mcycle[63:32] <= csr_wb;
		end
		else if (~mcountinhibit[0])
		begin
			mcycle <= mcycle + 64'b1;
		end


		// Instruction retire counter

		if (csr_[12'hb02])
		begin
			minstret[31:0] <= csr_wb;
		end
		else if (csr_[12'hb82])
		begin
			minstret[63:32] <= csr_wb;
		end
		else if (~mcountinhibit[2])
		begin
			minstret <= minstret + {63'b0, ~(exception_trap | interrupt_trap | wfi)};
		end


		// Configurable performance counters
		
		for (i = 3; i < 32; i++)
		begin
			if (csr_[{7'hb0, i[4:0]}])
			begin
				mhpmcounter[i][31:0] <= csr_wb;
			end
			else if (csr_[{7'hb8, i[4:0]}])
			begin
				mhpmcounter[i][63:32] <= csr_wb;
			end
			else if (~mcountinhibit[i])
			begin
				case (mhpmevent[i])
					1: mhpmcounter[i] <= mhpmcounter[i] + {63'b0, exception_trap};
					2: mhpmcounter[i] <= mhpmcounter[i] + {63'b0, interrupt_trap};
					3: mhpmcounter[i] <= mhpmcounter[i] + {63'b0, breakpoint};
					4: mhpmcounter[i] <= mhpmcounter[i] + {63'b0, ecall};
					default:;
				endcase
			end
		end


		// Misc. CSR writeback

		case (csr)
			12'h304:	mie <= csr_wb;
			12'h305:	mtvec <= csr_wb;
			12'h320:	mcountinhibit <= csr_wb;
			12'h340:	mscratch <= csr_wb;
			default:;
		endcase

		case (csr[11:5])
			7'h19:	mhpmevent[csr[4:0]] <= csr_wb;
			7'h58:	mhpmcounter[csr[4:0]][31:0] <= csr_wb;
			7'h5c:	mhpmcounter[csr[4:0]][63:32] <= csr_wb;
			default:;
		endcase
	end
end
endmodule
