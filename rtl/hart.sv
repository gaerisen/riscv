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
logic [31:0] imm;
logic [4:0] rd_dec;

// Decode->Execute wires
logic [31:0] rs1_value;
logic [31:0] rs2_value;

// Execute pipeline regs
logic [31:0] pc_exe;
logic branch_taken;
logic [31:0] result_exe;
ctrl_t ctrl_exe;
logic [4:0] rd_exe;

// Memacc pipeline regs
logic [31:0] pc_mem;
logic [31:0] result_mem;
logic [4:0] rd_mem;
ctrl_t ctrl_mem;

// Memacc->Writeback wires
logic [31:0] wb_next;

//======================================
//      REGISTER FILE (NAIVE)
//======================================

logic [31:0] irf [32] /*verilator public*/;

always_comb
begin
        wb_next = 0;
        
        if (ctrl_mem.wb & rd_mem != 0) begin
                unique case (ctrl_mem.wb_src)
                ALU: begin
                        wb_next = result_mem;
                end
                MEM: begin
                        wb_next = 0; // TODO: Make this real when mem stage added
                end
                PC4: begin
                        wb_next = pc_mem + 4;
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

//====================================
//      PIPELINE
//====================================

fetch fetch (
        .*,

        .jump(ctrl_exe.jump),
        .branch(ctrl_exe.branch),
        .alu_result(result_exe),

        .sys_redirect(0),
        .sys_vec(0),

        .pc_o(pc_fet),
        .instr_o(instr),
        .valid_o(valid),
        .flush_o(flush)
);

decoder decoder (
        .*,

        .flush(0),
        .stall(~valid),

        .instr_i(instr),

        .rs1_o(rs1),
        .rs2_o(rs2),
        .imm_o(imm),
        .rd_o(rd_dec),

        .system_o(system_dec),
        .ctrl_o(ctrl_dec)
);

// Decode stage register forwarding
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_dec <= 0;
        end
        else begin
                pc_dec <= pc_fet;
        end
end

// Operand forwarding/register read
always_comb
begin
        if (rs1 == 0)
                rs1_value = 0;
        else if (rs1 == rd_exe)
                rs1_value = result_exe;
        else if (rs1 == rd_mem)
                rs1_value = result_mem;
        else
                rs1_value = irf[rs1];

        if (rs2 == 0)
                rs2_value = 0;
        else if (rs2 == rd_exe)
                rs2_value = result_exe;
        else if (rs2 == rd_mem)
                rs2_value = result_mem;
        else
                rs2_value = irf[rs2];
end

alu alu (
        .*,

        .stall(0), // If decoder stalls, alu will receive NOP, so no need

        .ctrl_i(ctrl_dec),
        
        .result_o(result_exe),
        .branch_o(branch_taken)
);

// Execute stage register forwarding
always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                pc_exe <= 0;
                ctrl_exe <= 0;
                rd_exe <= 0;
        end
        else begin
                pc_exe <= pc_dec;
                ctrl_exe <= ctrl_dec;
                rd_exe <= rd_dec;
        end
end

// Memacc stage register forwarding
always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                pc_mem <= 0;
                ctrl_mem <= 0;
                rd_mem <= 0;
                result_mem <= 0;
        end
        else begin
                pc_mem <= pc_exe;
                ctrl_mem <= ctrl_exe;
                rd_mem <= rd_exe;
                result_mem <= result_exe;
        end
end

endmodule // core
