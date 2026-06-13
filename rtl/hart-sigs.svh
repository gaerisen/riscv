logic exception;
logic trapret;
trap_cause_e trap_cause;
logic rob_stall;
logic flush;
logic sys_redirect;
logic [31:0] sys_vec;

logic [31:0] pc_fet;
instr_t instr;
logic valid;

logic issue_next;
logic [4:0] rs1;
logic [4:0] rs2;
logic [11:0] csrs;
logic [31:0] rs1_val;
logic [31:0] rs2_val;
logic [31:0] csr_read;

logic [31:0] pc_dec;
logic [4:0] rs1_dec;
logic [4:0] rs2_dec;
logic [11:0] csrs_dec;
logic [4:0] rd_dec;
logic [31:0] rs1_val_dec;
logic [31:0] rs2_val_dec;
logic [31:0] csr_val_dec;
logic [31:0] imm;
ctrl_t ctrl_dec;
logic issue;

logic [31:0] rs1_value;
logic [31:0] rs2_value;
logic [31:0] csr_value;
logic [31:0] alu_result;
logic branch_taken;
logic [31:0] csr_result;
logic ready_exe_next;
logic [31:0] result_exe_next;
logic [31:0] target_addr_exe_next;

logic [31:0] pc_exe;
logic [31:0] target_addr_exe;
logic [31:0] csr_result_exe;
logic [31:0] rd_exe;
ctrl_t ctrl_exe;
logic ready_exe;
logic [31:0] result_exe;
logic branch_taken_exe;
wire [ROB_BITS-1:0] rob_ptr_exe;

logic commit;
logic store_commit;
logic branch_commit;
logic [31:0] rd_commit;
logic [31:0] wb_commit;
logic [11:0] csrd_commit;
logic [31:0] csrwb_commit;
logic irf_we;
