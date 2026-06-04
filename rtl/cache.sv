`timescale 1ps / 1ps
module cache
import rv32::*;
#(
        parameter int XLEN = 32,

        parameter int LINE_WIDTH = 8,
        parameter int NUM_LINES = 8,

        localparam int OFFSET_BITS = $clog2(LINE_WIDTH),
        localparam int INDEX_BITS = $clog2(NUM_LINES),
        localparam int TAG_BITS = XLEN - INDEX_BITS - OFFSET_BITS,

        localparam int TAG_HI = XLEN - 1,
        localparam int TAG_LO = OFFSET_BITS + INDEX_BITS,

        localparam int INDEX_HI = OFFSET_BITS + INDEX_BITS - 1,
        localparam int INDEX_LO = OFFSET_BITS,

        localparam int OFFSET_HI = OFFSET_BITS - 1
)(
        input clk,
        input rst,

        mem_ifc.periph cpu_ifc,
        input store_funct3_e st_op,     // Particular to the CPU interface to
                                        // respect SBs and SHs

        mem_ifc.ctrlr mem_ctrl_ifc
);

typedef struct {
        logic valid;
        logic dirty;
        logic [TAG_BITS-1:0] tag;
        logic [7:0] data [LINE_WIDTH-1:0];
} cache_line_t;

/* typedef enum logic [1:0] {
        IDLE,
        WRITING,
        READING
} state_e;

state_e state; */

cache_line_t mem [NUM_LINES-1:0];

logic [TAG_BITS-1:0] tag;
logic [INDEX_BITS-1:0] index;
logic [OFFSET_BITS-1:0] offset;

assign tag = cpu_ifc.addr[TAG_HI:TAG_LO];
assign index = cpu_ifc.addr[INDEX_HI:INDEX_LO];
assign offset = cpu_ifc.addr[OFFSET_HI:0];

// Asynchronous read logic
always_comb
begin
        cpu_ifc.ready = 0;
        cpu_ifc.data_rd = 0;

        if (cpu_ifc.valid & (mem[index].tag == tag)) begin
                cpu_ifc.ready <= 1;
                cpu_ifc.data_rd <= {    mem[index].data[offset+3],
                                        mem[index].data[offset+2],
                                        mem[index].data[offset+1],
                                        mem[index].data[offset+0] };
        end

        if (rst) begin
                cpu_ifc.ready = 0;
                cpu_ifc.data_rd = 0;
        end
end

// Synchronous write logic
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                for (int i = 0; i < NUM_LINES; i++) begin
                        for (int j = 0; j < LINE_WIDTH; j++) begin
                                mem[i].data[j] <= 0;
                        end
                end
        end
        else if (cpu_ifc.valid) begin
                if (mem[index].tag == tag) begin
                        if (cpu_ifc.we) begin
                                unique case (st_op)
                                SB: mem[index].data[offset] <=
                                                cpu_ifc.data_wr[7:0];
                                SH: begin
                                        mem[index].data[offset+1] <=
                                                cpu_ifc.data_wr[15:8];
                                        mem[index].data[offset] <=
                                                cpu_ifc.data_wr[7:0];
                                end
                                SW: begin
                                        mem[index].data[offset+3] <=
                                                cpu_ifc.data_wr[31:24];
                                        mem[index].data[offset+2] <=
                                                cpu_ifc.data_wr[23:16];
                                        mem[index].data[offset+1] <=
                                                cpu_ifc.data_wr[15:8];
                                        mem[index].data[offset] <=
                                                cpu_ifc.data_wr[7:0];
                                end
                                endcase
                        end
                end
        end
end

endmodule // cache
