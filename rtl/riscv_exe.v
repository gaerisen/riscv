module riscv_exe (
        input   wire            clk,
        input   wire            rst,

        input   wire    [31:0]  pc_i,

        input   wire    [7:0]   funct3,
        input   wire    [127:0] funct7,

        input   wire    [31:0]  alu_in1,
        input   wire    [31:0]  alu_in2,

        input   wire    [31:0]  agu_in1,
        input   wire    [31:0]  agu_in2,

        input   wire    [31:0]  csru_in1,
        input   wire    [31:0]  csru_in2,

        output  reg     [31:0]  pc_o,

        output  reg     [31:0]  alu,
        output  reg     [31:0]  agu,
        output  reg     [31:0]  csru,
        output  reg             bcu
);

always @(posedge clk) begin
        if (rst) begin
                pc_o <= 0;
                alu <= 0;
                agu <= 0;
                csru <= 0;
                bcu <= 0;
        end else begin
                pc_o <= pc_i;
                alu <=	funct3[0] ?	(funct7[32] ?	alu_in1 - alu_in2 :
                                                        alu_in1 + alu_in2 ) :
                        funct3[1] ?	alu_in1 << alu_in2 :
                        funct3[2] ?	{31'b0, alu_in1 < alu_in2} :
                        funct3[3] ?	{31'b0, $signed(alu_in1) < $signed(alu_in2)} :
                        funct3[4] ?	(funct7[32] ?	alu_in1 >>> alu_in2 :
                                                        alu_in1 >> alu_in2 ) :
                        funct3[5] ?	alu_in1 ^ alu_in2 :
                        funct3[6] ?	alu_in1 | alu_in2 :
                        funct3[7] ?	alu_in1 & alu_in2 :
                                        32'b0;


                agu <=	agu_in1 + agu_in2;

                csru <=	funct3[1] | funct3[5] ? csru_in2 :
                        funct3[2] | funct3[6] ?	csru_in1 | csru_in2 :
                        funct3[3] | funct3[7] ?	csru_in1 & ~csru_in2 :
                                                32'b0;

                bcu <=	funct3[0] ?	alu_in1 == alu_in2 :
                        funct3[1] ?	alu_in1 != alu_in2 :
                        funct3[4] ?	alu_in1 < alu_in2 :
                        funct3[5] ?	alu_in1 >= alu_in2 :
                        funct3[6] ?	$signed(alu_in1) < $signed(alu_in2) :
                        funct3[7] ?	$signed(alu_in1) >= $signed(alu_in2) :
                                        1'b0;
        end
end
endmodule
