`timescale 1ps / 1ps
module cache
import rv32::*;
#(
        parameter int XLEN = 32,

        parameter int LINE_WIDTH = 64,
        parameter int NUM_LINES = 16,

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

        input [31:0] cpu_addr,
        input [31:0] cpu_data_i,
        input cpu_valid,
        input cpu_we,

        output logic [31:0] cpu_data_o,
        output logic cpu_ready,

        input store_funct3_e st_op,    // Particular to the CPU interface to
                                        // respect SBs and SHs

        output logic [31:0] mem_addr,
        output logic [(8 * LINE_WIDTH)-1:0] mem_data_o,
        output logic mem_valid,
        output logic mem_we,

        input [(8 * LINE_WIDTH)-1:0] mem_data_i,
        input mem_ready
);

typedef logic [LINE_WIDTH-1:0][7:0] raw_line_t;

typedef struct {
        logic valid;
        logic dirty;
        logic [TAG_BITS-1:0] tag;
        raw_line_t data;
} cache_line_t;

typedef enum logic [1:0] {
        IDLE,
        BUSY_WR,
        BUSY_RD
} state_e;

state_e state;
state_e state_next;

cache_line_t mem [NUM_LINES-1:0];

logic mem_valid_next;
logic mem_we_next;
logic [XLEN-1:0] mem_addr_next;
logic [(8 * LINE_WIDTH)-1:0] mem_data_o_next;

logic [TAG_BITS-1:0] tag;
logic [INDEX_BITS-1:0] index;
logic [OFFSET_BITS-1:0] offset;

assign tag = cpu_addr[TAG_HI:TAG_LO];
assign index = cpu_addr[INDEX_HI:INDEX_LO];
assign offset = cpu_addr[OFFSET_HI:0];

initial begin
        $dumpfile("cache.vcd");
        $dumpvars(0, cache);
end

logic hit;
logic miss;

assign hit = cpu_valid & mem[index].valid & (mem[index].tag == tag);
assign miss = cpu_valid & !(mem[index].valid & (mem[index].tag == tag));

raw_line_t line_data_next;
logic line_valid_next;
logic [TAG_BITS-1:0] line_tag_next;

// FSM switching logic
always_comb
begin
        state_next = state;
        mem_valid_next = mem_valid;
        mem_we_next = mem_we;
        mem_addr_next = mem_addr;
        mem_data_o_next = mem_data_o;

        case(state)
        IDLE: begin
                if (miss) begin
                        if (mem[index].dirty) begin
                                mem_we_next = 1;
                                mem_data_o_next = (8*LINE_WIDTH)'(mem[index].data);
                                state_next = BUSY_WR;
                        end
                        else begin
                                state_next = BUSY_RD;
                        end

                        // TODO: figure out how to parameterize the stupid
                        // 0 length at the tail
                        mem_addr_next = {mem[index].tag, index, 6'b0};
                        mem_valid_next = 1;
                end
        end

        BUSY_WR: begin
                if (mem_ready) begin
                        mem_we_next = 0;
                        mem_data_o_next = 0;
                        mem_addr_next = cpu_addr;
                        state_next = BUSY_RD;   // Write-back: We only read if
                                                // we've had a miss, so always
                                                // read after write
                end
        end

        BUSY_RD: begin
                if (mem_ready) begin
                        mem_valid_next = 0;
                        mem_addr_next = 0;
                        state_next = IDLE;
                end
        end

        default:;
        endcase
end

// State machine and memory access flip-flops
always_ff @(posedge clk or posedge rst)
begin
        if (rst) begin
                state <= IDLE;
                mem_valid <= 0;
                mem_we <= 0;
                mem_addr <= 0;
                mem_data_o <= 0;
        end
        else begin
                state <= state_next;
                mem_valid <= mem_valid_next;
                mem_we <= mem_we_next;
                mem_addr <= mem_addr_next;
                mem_data_o <= mem_data_o_next;
        end
end

// Writeback construction
always_comb
begin
        line_data_next = mem[index].data;
        line_valid_next = mem[index].valid;
        line_tag_next = mem[index].tag;

        if (hit & cpu_we) begin
                case (st_op)
                SB: begin
                        line_data_next[offset] = cpu_data_i[7:0];
                end

                SH: begin
                        line_data_next[offset+1] = cpu_data_i[15:8];
                        line_data_next[offset] = cpu_data_i[7:0];
                end

                SW: begin
                        line_data_next[offset+3] = cpu_data_i[31:24];
                        line_data_next[offset+2] = cpu_data_i[23:16];
                        line_data_next[offset+1] = cpu_data_i[15:8];
                        line_data_next[offset] = cpu_data_i[7:0];
                end

                default:;
                endcase
        end

        if ((state == BUSY_RD) & mem_ready) begin
                line_data_next = raw_line_t'(mem_data_i);
                line_valid_next = 1;
                line_tag_next = tag;
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
                        mem[i].valid = 0;
                        mem[i].dirty = 0;
                        mem[i].tag = 0;
                end
        end
        else begin
                mem[index].data <= line_data_next;
                mem[index].valid <= line_valid_next;
                mem[index].tag <= line_tag_next;
                if (hit & cpu_we) begin
                        mem[index].dirty <= 1;
                end
        end
end

// Read logic
always_comb
begin
        cpu_ready = 0;
        cpu_data_o = 0;

        // For now, we'll only provide reads during IDLE state. In the future we
        // might be able to provide unrelated reads in other states by latching
        // write miss details and handling those internally
        if (state == IDLE) begin
                // Always fetch data to take advantage of parallelism
                cpu_data_o = {  mem[index].data[offset+3],
                                mem[index].data[offset+2],
                                mem[index].data[offset+1],
                                mem[index].data[offset+0] };

                // Validate read if there's a hit.
                cpu_ready = hit;
        end

        if (rst) begin
                cpu_ready = 0;
                cpu_data_o = 0;
        end
end

endmodule // cache
