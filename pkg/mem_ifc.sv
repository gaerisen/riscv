`timescale 1ps / 1ps

// Keeping this in case I want to go back to it later. Modports seem useful-ish?
// Maybe I just don't get the point. Either way I can't unit test with it.
/* interface mem_ifc
#(
        parameter int ADDR_WIDTH = 32,
        parameter int DATA_WIDTH = 32
);

logic [ADDR_WIDTH-1:0] addr;
logic [DATA_WIDTH-1:0] data_wr;
logic valid;    // Request is valid
logic we;       // Request is a write

logic [DATA_WIDTH-1:0] data_rd;
logic ready;    // Result is ready

modport ctrlr (
        output addr, data_wr, valid, we,
        input data_rd, ready
);

modport periph (
        output data_rd, ready,
        input addr, data_wr, valid, we
);

endinterface */

package mem_ifc;

class mem_ifc
#(
        parameter int ADDR_WIDTH = 32,
        parameter int DATA_WIDTH = 32
);

logic [ADDR_WIDTH-1:0] addr;
logic [DATA_WIDTH-1:0] data_wr;
logic valid;    // Request is valid
logic we;       // Request is a write

logic [DATA_WIDTH-1:0] data_rd;
logic ready;    // Result is ready

endclass

endpackage
