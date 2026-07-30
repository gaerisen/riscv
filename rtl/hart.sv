`timescale 1ps / 1ps
module hart
import rv32::*;
#(
        parameter int ROB_LEN = 64,
        parameter int PRF_SIZE = 128,
        parameter int IQ_ENTRIES = 4,
        parameter int LSQ_LEN = 32
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
        .*,
        .external_stall(~i_data_ready)
);
defparam ctrl_ifc.PRF_SIZE = PRF_SIZE;

fet_to_dec_ifc fet_dec_ifc();

dispatch_ifc dispatch_ifc();
defparam dispatch_ifc.PRF_SIZE = PRF_SIZE;
defparam dispatch_ifc.ROB_LEN = ROB_LEN;

issue_ifc issue_ifc();
defparam issue_ifc.PRF_SIZE = PRF_SIZE;

cdb_ifc cdb_ifc();
defparam cdb_ifc.ROB_LEN = ROB_LEN;
defparam cdb_ifc.PRF_SIZE = PRF_SIZE;

commit_ifc commit_ifc();
defparam commit_ifc.PRF_SIZE = PRF_SIZE;


// Integer register file
prf prf(.*);
defparam prf.PRF_SIZE = PRF_SIZE;

// Control/status register file
csrf csrf(.*);

// Pipeline stages

fetch fetch (.*);

decode decode (.*);
defparam decode.PRF_SIZE = PRF_SIZE;

iq iq (.*);
defparam iq.PRF_SIZE = PRF_SIZE;
defparam iq.ROB_SIZE = ROB_LEN;
defparam iq.NUM_ENTRIES = IQ_ENTRIES;

execute execute (.*);
defparam execute.PRF_SIZE = PRF_SIZE;

logic update;
logic [$clog2(ROB_LEN)-1:0] update_tag;
logic [$clog2(PRF_SIZE)-1:0] update_prd;
logic [31:0] update_data;

lsu lsu (
        .dispatch(dispatch_ifc.dispatch),
        .dispatch_tag(dispatch_ifc.tag),
        .new_prd(dispatch_ifc.prd_new),
        .ctrl_word(dispatch_ifc.ctrl_word),

        .issue(issue_ifc.issue),
        .rs1_val(issue_ifc.rs1_val),
        .rs2_val(issue_ifc.rs2_val),
        .imm(issue_ifc.imm),

        .update(update),
        .update_tag(update_tag),
        .update_prd(update_prd),
        .update_data(update_data),

        .commit(commit_ifc.commit),
        .commit_store(commit_ifc.store),

);
defparam lsu.FIFO_LEN = LSQ_LEN;


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
