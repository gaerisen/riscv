`timescale 1ps / 1ps
module cache
#(
        parameter int XLEN = 32,

        parameter int LINE_WIDTH = 8,
        parameter int NUM_LINES = 8,

        localparam int OFFSET_BITS = $clog2(LINE_WIDTH),
        localparam int INDEX_BITS = $clog2(NUM_LINES),
        localparam int TAG_BITS = XLEN - INDEX_BITS - OFFSET_BITS
)(
        input clk,
        input rst,

        input [XLEN-1:0] addr,
        input [XLEN-1:0] data_i,

        output logic [XLEN-1:0] data_o
);

typedef struct packed {
        logic valid;
        logic dirty;
        logic [TAG_BITS-1:0] tag;
        logic [LINE_WIDTH-1:0] data;
} cache_line_t;

cache_line_t x [NUM_LINES-1:0];

endmodule // icache
