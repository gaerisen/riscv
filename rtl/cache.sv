`timescale 1ps / 1ps
module cache
import rv32::*;
#(
        parameter int ADDR_LEN = 32,

        parameter int LINE_WIDTH = 64,
        parameter int NUM_LINES = 16,
        parameter int NUM_WAYS = 2,

        localparam int NUM_SETS = NUM_LINES / NUM_WAYS,
        localparam int WAY_IDX_BITS = $clog2(NUM_WAYS),

        localparam int OFFSET_BITS = $clog2(LINE_WIDTH),
        localparam int INDEX_BITS = $clog2(NUM_SETS),
        localparam int TAG_BITS = ADDR_LEN - INDEX_BITS - OFFSET_BITS,

        localparam int TAG_HI = ADDR_LEN - 1,
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

cache_line_t cache [NUM_SETS-1:0][NUM_WAYS-1:0];

logic mem_valid_next;
logic mem_we_next;
logic [ADDR_LEN-1:0] mem_addr_next;
logic [(8 * LINE_WIDTH)-1:0] mem_data_o_next;

logic [TAG_BITS-1:0] tag;
logic [INDEX_BITS-1:0] index;
logic [OFFSET_BITS-1:0] offset;

logic [WAY_IDX_BITS-1:0] hit;
logic miss;

// FIFO replacement pointer. Always points to next way to be written to; if the
// valid bit is set, we evict first.
logic [WAY_IDX_BITS-1:0] fifo_head [0:NUM_SETS-1];
logic [WAY_IDX_BITS-1:0] fifo_head_next [0:NUM_SETS-1];
logic fifo_inc;

assign tag = cpu_addr[TAG_HI:TAG_LO];
assign index = cpu_addr[INDEX_HI:INDEX_LO];
assign offset = cpu_addr[OFFSET_HI:0];

initial begin
        $dumpfile("cache.vcd");
        $dumpvars(0, cache);
end

raw_line_t line_data_next;
logic line_valid_next;
logic [TAG_BITS-1:0] line_tag_next;

// Hit/miss detection logic
always_comb
begin
        miss = cpu_valid;
        hit = 0;

        for (int i = 0; i < NUM_WAYS; i++) begin
                miss = miss & !(cache[index][i].valid & (cache[index][i].tag == tag));

                if (cpu_valid & cache[index][i].valid & (cache[index][i].tag == tag))
                        hit = WAY_IDX_BITS'(unsigned'(i));
        end
end

// FSM switching logic
always_comb
begin
        state_next = state;
        mem_valid_next = mem_valid;
        mem_we_next = mem_we;
        mem_addr_next = mem_addr;
        mem_data_o_next = mem_data_o;
        fifo_head_next[index] = fifo_head[index] + 1;
        fifo_inc = 0;

        case(state)
        IDLE: begin
                if (miss) begin
                        if (cache[index][fifo_head_next[index]].dirty) begin
                                mem_we_next = 1;
                                mem_data_o_next = (8*LINE_WIDTH)'(cache[index][fifo_head_next[index]].data);
                                state_next = BUSY_WR;
                        end
                        else begin
                                state_next = BUSY_RD;
                        end

                        // TODO: figure out how to parameterize the stupid
                        // 0 length at the tail
                        mem_addr_next = {cache[index][fifo_head_next[index]].tag, index, 6'b0};
                        mem_valid_next = 1;
                        fifo_inc = 1;
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
                if (fifo_inc)
                        fifo_head[index] <= fifo_head_next[index];
        end
end


// Writeback construction
always_comb
begin
        line_data_next = cache[index][fifo_head[index]].data;
        line_valid_next = cache[index][fifo_head[index]].valid;
        line_tag_next = cache[index][fifo_head[index]].tag;

        if (!miss & cpu_we) begin
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
                for (int i = 0; i < NUM_SETS; i++) begin
                        for (int j = 0; j < NUM_WAYS; j++) begin
                                cache[i][j].data <= 0;
                                cache[i][j].valid <= 0;
                                cache[i][j].dirty <= 0;
                                cache[i][j].tag <= 0;
                        end
                end
        end
        else begin
                cache[index][fifo_head[index]].data <= line_data_next;
                cache[index][fifo_head[index]].valid <= line_valid_next;
                cache[index][fifo_head[index]].tag <= line_tag_next;
                if (!miss & cpu_we) begin
                        cache[index][fifo_head[index]].dirty <= 1;
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
                cpu_data_o = {  cache[index][hit].data[offset+3],
                                cache[index][hit].data[offset+2],
                                cache[index][hit].data[offset+1],
                                cache[index][hit].data[offset+0] };

                // Validate read if there's a hit.
                cpu_ready = !miss;
        end

        if (rst) begin
                cpu_ready = 0;
                cpu_data_o = 0;
        end
end

endmodule // cache
