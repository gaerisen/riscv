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
irf irf(.*);

// Control/status register file
csrf csrf(.*);

// Pipeline stages

fetch fetch (.*);

decode decode (.*);

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
                d_addr = commit_ifc.dest;
                d_data_o = commit_ifc.value;
        end
end
endmodule // hart
