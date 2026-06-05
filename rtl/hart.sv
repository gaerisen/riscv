`timescale 1ps / 1ps

module hart
import rv32::*;
#()
(
        input clk,
        input rst,

        input i_data_ready,
        input [31:0] i_data,
        
        output logic [31:0] i_addr
);

// Fetch pipeline registers
instr_t instr;
logic [31:0] pc_fet;
logic valid;
logic flush;

// Fetch->Decode wires
logic [4:0] rs1;
logic [4:0] rs2;
logic [31:0] rs1_val;
logic [31:0] rs2_val;
logic [11:0] csrs;
logic [31:0] csr_read;
logic [31:0] csr_val_dec_next;

// Decode pipeline regs
logic [31:0] pc_dec;
ctrl_t ctrl_dec;
system_t system_dec;
logic [31:0] rs1_val_dec;
logic [31:0] rs2_val_dec;
logic [31:0] csr_val_dec;
logic [4:0] rs1_dec;
logic [4:0] rs2_dec;
logic [11:0] csrs_dec;
logic [31:0] imm;
logic [4:0] rd_dec;

// Decode->Execute wires
logic [31:0] rs1_value;
logic [31:0] rs2_value;
logic [31:0] csr_value;

// Execute pipeline regs
logic [31:0] pc_exe;
logic branch_taken;
logic [31:0] result_exe;
logic [4:0] rd_exe;
logic [31:0] csr_result_exe;
logic [11:0] csrd_exe;
logic [31:0] csr_value_exe;
logic [31:0] rs2_val_exe;
ctrl_t ctrl_exe;
system_t system_exe;

// Memacc pipeline regs
logic [4:0] rd_mem;
logic [31:0] csr_result_mem;
logic [11:0] csrd_mem;
ctrl_t ctrl_mem /*verilator public*/;
system_t system_mem;
logic [31:0] wb_mem;
logic [31:0] rs2_val_mem /*verilator public*/;

// Memacc->Writeback wires
logic [31:0] wb_next;

// Trap wires
logic sys_redirect;
logic [31:0] sys_vec;

// Integer register file
irf irf(
        .*,

        .we(ctrl_mem.irf_wb),
        .rd(rd_mem),
        .rd_val(wb_mem)
);

// Control/status register file
csrf csrf(
        .*,

        .csrs_value(csr_read),

        .csrd(csrd_mem),
        .csr_result(csr_result_mem),

        .sys_word(system_mem)
);

//==============================================================================
//                              PIPELINE
//==============================================================================
//======================================
//      (1) Fetch
//======================================

fetch fetch (
        .*,

        .jump(ctrl_exe.jump),
        .branch(ctrl_exe.branch),
        .alu_result(result_exe),

        .pc_o(pc_fet),
        .instr_o(instr),
        .valid_o(valid),
        .flush_o(flush)
);

//======================================
//      (2a) Reg read 
//======================================

assign rs1 = instr.r.rs1;
assign rs2 = instr.r.rs2;
assign csrs = instr.i.imm11_0;

// Register read happens here, but we also need one pass of operand forwarding
// from late in the pipeline to make sure we have an up-to-date fallback for the
// second pass
always_comb
begin
        csr_val_dec_next = csr_read;

        if (ctrl_mem.csr_wb & (csrs == csrd_mem))
                csr_val_dec_next = csr_result_mem;
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                rs1_dec <= 0;
                rs2_dec <= 0;
                csrs_dec <= 0;
                csr_val_dec <= 0;
        end
        else begin
                rs1_dec <= rs1;
                rs2_dec <= rs2;
                rs1_val_dec <= rs1_val;
                rs2_val_dec <= rs2_val;
                csrs_dec <= csrs;
                csr_val_dec <= csr_val_dec_next;
        end
end
        

//======================================
//      (2b) Decode
//======================================

decoder decoder (
        .*,

        .stall(~valid),

        .instr_i(instr),

        .imm_o(imm),
        .rd_o(rd_dec),

        .system_o(system_dec),
        .ctrl_o(ctrl_dec)
);

always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                pc_dec <= 0;
        end
        else begin
                pc_dec <= pc_fet;
        end
end


//======================================
//      (3) Execute        
//======================================

// Operand forwarding
always_comb
begin
        rs1_value = rs1_val_dec;
        rs2_value = rs2_val_dec;
        csr_value = csr_val_dec;

        if (rs1_dec == 0)
                rs1_value = 0;
        else if (ctrl_exe.irf_wb & (rs1_dec == rd_exe))
                rs1_value = wb_next;
        else if (ctrl_mem.irf_wb & (rs1_dec == rd_mem))
                rs1_value = wb_mem;

        if (rs2_dec == 0)
                rs2_value = 0;
        else if (ctrl_exe.irf_wb & (rs2_dec == rd_exe))
                rs2_value = wb_next;
        else if (ctrl_mem.irf_wb & (rs2_dec == rd_mem))
                rs2_value = wb_mem;

        if (ctrl_exe.csr_wb & (csrs_dec == csrd_exe))
                csr_value = csr_result_exe;
        else if (ctrl_mem.csr_wb & (csrs_dec == csrd_mem))
                csr_value = csr_result_mem;
end

// Main ALU for single-cycle arithmetic and logic
alu alu (
        .*,

        .stall(0),

        .ctrl_i(ctrl_dec),
        
        .result_o(result_exe),
        .branch_o(branch_taken)
);

// Execution unit for Zicsr instructions
csru csru (
        .*,

        .ctrl_i(ctrl_dec),

        .csr_old(csr_value),

        .csr_new(csr_result_exe)
);

always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                pc_exe <= 0;
                ctrl_exe <= 0;
                rs2_val_exe <= 0;
                system_exe <= 0;
                rd_exe <= 0;
                csrd_exe <= 0;
                csr_value_exe <= 0;
        end
        else begin
                pc_exe <= pc_dec;
                ctrl_exe <= ctrl_dec;
                rs2_val_exe <= rs2_value;
                system_exe <= system_dec;
                rd_exe <= rd_dec;
                csrd_exe <= csrs_dec; // Zicsr is atomic swap --> csrd = csrs
                csr_value_exe <= csr_value;
        end
end


//======================================
//      (4) Memory Access
//======================================

// Construct writeback value now so it's available for forwarding
always_comb
begin
        wb_next = 0;
        
        if (ctrl_exe.irf_wb & rd_exe != 0) begin
                unique case (ctrl_exe.wb_src)
                WB_ALU: begin
                        wb_next = result_exe;
                end
                WB_MEM: begin
                        wb_next = 0; // TODO: Override this after memacc resolves
                end
                WB_PC4: begin
                        wb_next = pc_exe + 4;
                end
                WB_CSR: begin
                        wb_next = csr_value_exe;
                end
                endcase
        end
end

// Memacc stage register forwarding
always_ff @(posedge clk or posedge rst)
begin
        if (rst | sys_redirect) begin
                ctrl_mem <= 0;
                system_mem <= 0;
                rs2_val_mem <= 0;
                rd_mem <= 0;
                csr_result_mem <= 0;
                csrd_mem <= 0;
                wb_mem <= wb_next;
        end
        else begin
                ctrl_mem <= ctrl_exe;
                system_mem <= system_exe;
                rs2_val_mem <= rs2_val_exe;
                rd_mem <= rd_exe;
                csr_result_mem <= csr_result_exe;
                csrd_mem <= csrd_exe;
                wb_mem <= wb_next;
        end
end

//======================================
//      (5) Writeback/Commit
//======================================

endmodule // core
