import riscv_pkg::*;

module alu #(
    parameter XLEN = 32
)(
    input  logic [XLEN-1:0] a,
    input  logic [XLEN-1:0] b,
    input  logic [3:0]      alu_ctrl_i,
    output logic [XLEN-1:0] result,
    output logic            zero
);

    alu_op_e alu_ctrl;
    assign alu_ctrl = alu_op_e'(alu_ctrl_i);

    always_comb begin
        case (alu_ctrl)
            ALU_ADD:  result = a + b;                             // ADD
            ALU_SUB:  result = a - b;                             // SUB
            ALU_AND:  result = a & b;                             // AND
            ALU_OR:   result = a | b;                             // OR
            ALU_XOR:  result = a ^ b;                             // XOR
            ALU_SLL:  result = a << b[4:0];                       // SLL (Shift Left Logical)
            ALU_SRL:  result = a >> b[4:0];                       // SRL (Shift Right Logical)
            ALU_SRA:  result = $signed(a) >>> b[4:0];             // SRA (Shift Right Arithmetic)
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 1 : 0; // SLT (Set Less Than Signed)
            ALU_SLTU: result = (a < b) ? 1 : 0;                   // SLTU (Set Less Than Unsigned)
            default:  result = {XLEN{1'b0}};
        endcase
    end

    assign zero = (result == {XLEN{1'b0}});

endmodule
