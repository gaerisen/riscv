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

// Decode pipeline regs
logic [31:0] pc_dec;
ctrl_t ctrl_dec;
system_t system_dec;
logic [4:0] rs1;
logic [4:0] rs2;
logic [11:0] csrs;
logic [31:0] rs1_read;
logic [31:0] rs2_read;
logic [31:0] csr_read;
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
ctrl_t ctrl_exe;
system_t system_exe;

// Memacc pipeline regs
logic [31:0] pc_mem;
logic [31:0] result_mem;
logic [4:0] rd_mem;
logic [31:0] csr_result_mem;
logic [11:0] csrd_mem;
logic [31:0] csr_value_mem;
ctrl_t ctrl_mem;
system_t system_mem;

// Memacc->Writeback wires
logic [31:0] wb_next;

// Trap wires
logic sys_redirect;
logic [31:0] sys_vec;

// Integer register file
logic [31:0] irf [32] /*verilator public*/;

// Control/status register file
csrf csrf(
        .*,

        .csr_rd(ctrl_dec.csr_op != NONE),
        .csrs_value(csr_read),

        .csrd(csrd_mem),
        .csr_wb(csr_result_mem),

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
//      (2) Decode/IRF read
//======================================

decoder decoder (
        .*,

        .flush(0),
        .stall(~valid),

        .instr_i(instr),

        .rs1_o(rs1),
        .rs2_o(rs2),
        .csr_o(csrs),
        .imm_o(imm),
        .rd_o(rd_dec),

        .system_o(system_dec),
        .ctrl_o(ctrl_dec)
);

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_dec <= 0;
                rs1_read <= 0;
                rs2_read <= 0;
        end
        else begin
                pc_dec <= pc_fet;
                rs1_read <= irf[rs1];
                rs2_read <= irf[rs2];
        end
end


//======================================
//      (3) Execute        
//======================================

// Operand forwarding
always_comb
begin
        if (rs1 == 0)
                rs1_value = 0;
        else if (rs1 == rd_exe)
                rs1_value = result_exe;
        else if (rs1 == rd_mem)
                rs1_value = result_mem;
        else
                rs1_value = rs1_read;

        if (rs2 == 0)
                rs2_value = 0;
        else if (rs2 == rd_exe)
                rs2_value = result_exe;
        else if (rs2 == rd_mem)
                rs2_value = result_mem;
        else
                rs2_value = rs2_read;

        if (csrs == csrd_exe)
                csr_value = csr_result_exe;
        else if (csrs == csrd_mem)
                csr_value = csr_result_mem;
        else
                csr_value = csr_read;
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
                system_exe <= 0;
                rd_exe <= 0;
                csrd_exe <= 0;
                csr_value_exe <= 0;
        end
        else begin
                pc_exe <= pc_dec;
                ctrl_exe <= ctrl_dec;
                system_exe <= system_dec;
                rd_exe <= rd_dec;
                csrd_exe <= csrs; // Zicsr is atomic swap --> csrd = csrs
                csr_value_exe <= csr_value;
        end
end


//======================================
//      (4) Memory Access
//======================================

// Memacc stage register forwarding
always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                pc_mem <= 0;
                ctrl_mem <= 0;
                system_mem <= 0;
                rd_mem <= 0;
                result_mem <= 0;
                csr_result_mem <= 0;
                csrd_mem <= 0;
                csr_value_mem <= 0;
        end
        else begin
                pc_mem <= pc_exe;
                ctrl_mem <= ctrl_exe;
                system_mem <= system_exe;
                rd_mem <= rd_exe;
                result_mem <= result_exe;
                csr_result_mem <= csr_result_exe;
                csrd_mem <= csrd_exe;
                csr_value_mem <= csr_value_exe;
        end
end

//======================================
//      (5) Writeback/Commit
//======================================

always_comb
begin
        wb_next = 0;
        
        if (ctrl_mem.wb & rd_mem != 0) begin
                unique case (ctrl_mem.wb_src)
                WB_ALU: begin
                        wb_next = result_mem;
                end
                WB_MEM: begin
                        wb_next = 0; // TODO: Make this real when mem stage added
                end
                WB_PC4: begin
                        wb_next = pc_mem + 4;
                end
                WB_CSR: begin
                        wb_next = csr_value_mem;
                end
                endcase
        end
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < 32; i++)
                        irf[i] <= 0;
        end
        else if (ctrl_mem.wb) begin
                irf[rd_mem] <= wb_next;
        end
end


endmodule // core
