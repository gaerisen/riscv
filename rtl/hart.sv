`timescale 1ps / 1ps
module hart
import rv32::*;
#(
        parameter int ROB_LEN = 32
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

global_ctrl_ifc ctrl_ifc();
fet_to_dec_ifc fet_dec_ifc();
fwding_ifc fwd_ifc();

issue_ifc issue_ifc();
defparam issue_ifc.ROB_LEN = ROB_LEN;

cdb_ifc cdb_ifc();
defparam cdb_ifc.ROB_LEN = ROB_LEN;

commit_ifc commit_ifc();

// Integer register file
irf irf(
        .*
);

// Control/status register file
csrf csrf(
        .*
);

//==============================================================================
//                              PIPELINE
//==============================================================================
//======================================
//      (1) Fetch
//======================================


fetch fetch (
        .*
);

//======================================
//      (2a) Reg read 
//======================================

logic [4:0] rs1_dec;
logic [4:0] rs2_dec;
logic [11:0] csrs_dec;
logic [31:0] csr_val_dec;
logic [31:0] rs1_val_dec;
logic [31:0] rs2_val_dec;

always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                rs1_dec <= 0;
                rs2_dec <= 0;
                rs1_val_dec <= 0; // direct from irf module
                rs2_val_dec <= 0; // direct from irf module
                csrs_dec <= 0;
                csr_val_dec <= 0;
        end
        else begin
                rs1_dec <= fet_dec_ifc.rs1;
                rs2_dec <= fet_dec_ifc.rs2;
                rs1_val_dec <= fet_dec_ifc.rs1_val; // direct from irf module
                rs2_val_dec <= fet_dec_ifc.rs2_val; // direct from irf module
                csrs_dec <= fet_dec_ifc.csrs;
                csr_val_dec <= fet_dec_ifc.csr_val;
        end
end

// [Temporary] give fwding network read values
always_comb
begin
        fwd_ifc.rs1 = rs1_dec;
        fwd_ifc.rs2 = rs2_dec;
        fwd_ifc.rs1_val = rs1_val_dec;
        fwd_ifc.rs2_val = rs2_val_dec;
end
        

//======================================
//      (2b) Decode
//======================================

decode decode (
        .*
);


//======================================
//      (3) Execute        
//======================================

execute execute (
        .*
);

//======================================
//      (4) Reorder & Commit
//======================================
rob rob (
        .*
);

defparam rob.ROB_LEN = ROB_LEN;

always_comb
begin
        d_addr = 0;
        d_valid = 0;
        d_data_o = 0;
        d_we = 0;
        d_st_op = SB;

        if (commit_ifc.store) begin
                d_valid = 1;
                d_we = 1;
                d_addr = commit_ifc.dest;
                d_data_o = commit_ifc.value;
        end
end
endmodule // hart
