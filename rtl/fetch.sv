module fetch
import rv32::*;
#()
(
        input clk,
        input rst,

        // I-mem interface signals
        input i_data_ready,
        input [31:0] i_data_i,

        output logic [31:0] i_addr,

        // Jump/branch signals
        input ctrl_t ctrl_word,
        input [31:0] alu_result,
        input branch_result,

        // System control signals
        input system_t system_word,
        input [31:0] mtvec,
        input [31:0] mepc,

        // Output to decode stage
        output logic [31:0] pc_o,
        output logic [31:0] instr_o,
        output logic valid_o
);

logic [31:0] pc_next;
logic [31:0] instr_next;
logic valid_next;

assign i_addr = pc_next; // Always be slamming the imem for whatever is next

always_comb
begin
        pc_next = pc_o + 32'h4;
        instr_next = i_data_i;
        valid_next = i_data_ready;

        if (ctrl_word.branch & branch_result)
                pc_next = alu_result;

        if (ctrl_word.jump)
                pc_next = alu_result;

        if (system_word.ecall | system_word.breakpoint | system_word.illegal)
                pc_next = mtvec;

        if (system_word.mret)
                pc_next = mepc;
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                pc_o <= 0;
                instr_o <= 0;
                valid_o <= 0;
        end else begin
                pc_o <= pc_next;
                instr_o <= instr_next;
                valid_o <= valid_next;
        end
end

endmodule // fetch
