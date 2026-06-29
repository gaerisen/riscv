`timescale 1ps / 1ps
module hart
import rv32::*;
#(
        parameter int ROB_LEN = 64,
        parameter int PRF_SIZE = 64
)(
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

global_ctrl_ifc ctrl_ifc(
        .external_stall(~i_data_ready)
);

fet_to_dec_ifc fet_dec_ifc();

issue_ifc issue_ifc();
defparam issue_ifc.ROB_LEN = ROB_LEN;

dispatch_ifc dispatch_ifc();

cdb_ifc cdb_ifc();
defparam cdb_ifc.ROB_LEN = ROB_LEN;

commit_ifc commit_ifc();

logic [63:0] prf_ready;
logic [5:0] prd_new;

// Integer register file
prf prf(
        .*,

        .prd_new_from_rat(prd_new)
);
defparam prf.PRF_SIZE = PRF_SIZE;

// Control/status register file
csrf csrf(.*);

// Pipeline stages

fetch fetch (.*);

issue issue (.*);

rs rs (.*);

execute execute (.*);

rob rob (.*);
defparam rob.ROB_LEN = ROB_LEN;

// Super basic store logic
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
                d_addr = 0;
                d_data_o = commit_ifc.value;
        end
end
endmodule // hart
