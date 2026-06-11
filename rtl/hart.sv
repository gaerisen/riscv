`timescale 1ps / 1ps
module hart
import rv32::*;
#(
        parameter int ROB_LEN = 32,
        localparam int ROB_BITS = $clog2(ROB_LEN)
)
(
        input clk,
        input rst,

        output logic [31:0] i_addr,

        input i_data_ready,
        input [31:0] i_data,

        output logic [31:0] d_addr,
        output logic d_valid,
        output logic d_we,
        output store_funct3_e d_st_op,
        output logic [31:0] d_data_o,

        input logic d_ready,
        input logic [31:0] d_data_i
);

// Fetch pipeline registers
instr_t instr;
logic [31:0] pc_fet;
logic valid;
logic spec_flush_fet;

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
logic [31:0] rs1_val_dec;
logic [31:0] rs2_val_dec;
logic [31:0] csr_val_dec;
logic [4:0] rs1_dec;
logic [4:0] rs2_dec;
logic [11:0] csrs_dec;
logic [31:0] imm;
logic [4:0] rd_dec;
logic issue;

// Decode->Execute wires
logic [31:0] rs1_value;
logic [31:0] rs2_value;
logic [31:0] csr_value;
logic alu_sel;
logic bu_sel;
logic csru_sel;

// Execute pipeline regs
logic [31:0] pc_exe;
logic branch_taken;
logic [31:0] alu_result_exe;
logic [4:0] rd_exe;
logic [31:0] csr_result_exe;
logic [11:0] csrd_exe;
logic [31:0] csr_value_exe;
logic [31:0] rs2_val_exe;
ctrl_t ctrl_exe;
logic alu_ready;
logic bu_ready;
logic csru_ready;


logic ready_exe;
logic [31:0] result_exe;

// Memacc pipeline regs
logic [4:0] rd_mem;
logic [31:0] csr_result_mem;
logic [11:0] csrd_mem;
ctrl_t ctrl_mem /*verilator public*/;
logic [31:0] wb_mem;

// Memacc->Writeback wires
logic [31:0] wb_next;

// Commit wires
logic commit;
logic store_commit;
logic branch_commit;
logic [31:0] rd_commit;
logic [31:0] wb_commit;
logic exception;
logic trapret;
trap_cause_e trap_cause;
logic rob_stall;
logic flush;

wire [ROB_BITS-1:0] rob_ptr_exe;

// Trap wires
logic sys_redirect;
logic [31:0] sys_vec;

logic irf_we;

assign irf_we = commit & !(branch_commit | store_commit);

// Integer register file
irf irf(
        .*,

        .we(irf_we),
        .rd(rd_commit[4:0]),
        .rd_val(wb_commit)
);

// Control/status register file
csrf csrf(
        .*,

        .csrs_value(csr_read),

        .csrd(csrd_mem),
        .csr_result(csr_result_mem)
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
        .branch(bu_ready),
        .alu_result(alu_result_exe),

        .pc_o(pc_fet),
        .instr_o(instr),
        .valid_o(valid),
        .flush_o(flush)
);

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                spec_flush_fet <= 0;
        end
        else begin
                spec_flush_fet <= flush;
        end
end

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

        if (ctrl_mem.csr_we & (csrs == csrd_mem))
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

        .stall(rob_stall),

        .instr_i(instr),

        .imm_o(imm),
        .rd_o(rd_dec),

        .ctrl_o(ctrl_dec)
);


always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                pc_dec <= 0;
                issue <= 0;
        end
        else if (rob_stall) begin
                issue <= 0;
        end
        else if (issue) begin
                pc_dec <= pc_fet;
                issue <= valid;
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
        else if (ctrl_exe.irf_we & (rs1_dec == rd_exe))
                rs1_value = wb_next;
        else if (ctrl_mem.irf_we & (rs1_dec == rd_mem))
                rs1_value = wb_mem;

        if (rs2_dec == 0)
                rs2_value = 0;
        else if (ctrl_exe.irf_we & (rs2_dec == rd_exe))
                rs2_value = wb_next;
        else if (ctrl_mem.irf_we & (rs2_dec == rd_mem))
                rs2_value = wb_mem;

        if (ctrl_exe.csr_we & (csrs_dec == csrd_exe))
                csr_value = csr_result_exe;
        else if (ctrl_mem.csr_we & (csrs_dec == csrd_mem))
                csr_value = csr_result_mem;
end

// Execution unit selection

assign bu_sel = issue & ctrl_dec.branch;
assign csru_sel = issue & ctrl_dec.csr_we;
assign alu_sel = issue & (ctrl_dec.irf_we | ctrl_dec.store);

// Ex unit for integral arithmetic and logic instructions
alu alu (
        .*,

        .flush(flush),

        .sel(alu_sel),

        .op(ctrl_dec.alu_op),
        .alt(ctrl_dec.alu_alt),
        .src1(ctrl_dec.alu_src1),
        .src2(ctrl_dec.alu_src2),
        
        .ready(alu_ready),
        .result(alu_result_exe)
);

// Ex unit for branch resolution
bu bu (
        .*,

        .flush(flush),

        .sel(bu_sel),
        .op(ctrl_dec.branch_op),

        .ready(bu_ready),
        .result(branch_taken)
);

// Ex unit for Zicsr instructions
csru csru (
        .*,

        .flush(flush),

        .sel(csru_sel),

        .op(ctrl_dec.csr_op),
        .src(ctrl_dec.csr_src),

        .csr_old(csr_value),

        .ready(csru_ready),
        .csr_new(csr_result_exe)
);

assign ready_exe = alu_ready | bu_ready | csru_ready |
                ctrl_exe.exception | ctrl_exe.wfi | ctrl_exe.trapret;

always_comb
begin
        result_exe = 0;

        if (alu_ready) begin
                if (ctrl_exe.store)
                        result_exe = rs2_val_exe;
                else if (ctrl_exe.jump)
                        result_exe = pc_exe + 4;
                else
                        result_exe = alu_result_exe;
        end
        else if (csru_ready)
                result_exe = csr_value_exe;
        else if (bu_ready)
                result_exe = {31'b0, branch_taken};
end

always_ff @(posedge clk or posedge rst)
begin
        if (rst | flush) begin
                pc_exe <= 0;
                ctrl_exe <= 0;
                rs2_val_exe <= 0;
                rd_exe <= 0;
                csrd_exe <= 0;
                csr_value_exe <= 0;
        end
        else begin
                pc_exe <= pc_dec;
                ctrl_exe <= ctrl_dec;
                rs2_val_exe <= rs2_value;
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
        
        if (ctrl_exe.irf_we & rd_exe != 0) begin
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
                rd_mem <= 0;
                csr_result_mem <= 0;
                csrd_mem <= 0;
                wb_mem <= wb_next;
        end
        else begin
                ctrl_mem <= ctrl_exe;
                rd_mem <= rd_exe;
                csr_result_mem <= csr_result_exe;
                csrd_mem <= csrd_exe;
                wb_mem <= wb_next;
        end
end

//======================================
//      (5) Writeback/Commit
//======================================
rob rob (
        .*,

        .issued_dest({27'b0, rd_dec}),
        .issued_ctrl(ctrl_dec),
        .issued_pc(pc_dec),

        .issued_ptr(rob_ptr_exe),
        
        .update_entry(ready_exe),
        .result(result_exe),
        .updated_dest(alu_result_exe),
        .entry_idx(rob_ptr_exe),

        .store(store_commit),
        .branch(branch_commit),
        .rd(rd_commit),
        .wb(wb_commit)
);

defparam rob.ROB_LEN = ROB_LEN;

always_comb
begin
        d_addr = 0;
        d_valid = 0;
        d_data_o = 0;
        d_we = 0;
        d_st_op = SB;

        if (store_commit) begin
                d_valid = 1;
                d_we = 1;
                d_addr = rd_commit;
                d_data_o = wb_commit;
        end
end
endmodule // hart
