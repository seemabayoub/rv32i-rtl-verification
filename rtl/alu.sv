import riscv_pkg::*;

// Arithmetic Logic Unit supporting all base RV32I operations
module alu #(
    parameter XLEN = 32
)(
    input  logic [XLEN-1:0] a,
    input  logic [XLEN-1:0] b,
    input  logic [3:0]      alu_ctrl_i,
    output logic [XLEN-1:0] result,
    output logic            zero
);

    // Cast raw 4-bit control input to enum for readable case decoding
    alu_op_e alu_ctrl;
    assign alu_ctrl = alu_op_e'(alu_ctrl_i);

    always_comb begin
        case (alu_ctrl)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];                        // Use lower 5 bits for shift amount
            ALU_SRL:  result = a >> b[4:0];                        // Logical right shift fills with zeros
            ALU_SRA:  result = $signed(a) >>> b[4:0];              // Arithmetic right shift preserves sign bit
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // Signed comparison
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;            // Unsigned comparison
            default:  result = {XLEN{1'b0}};
        endcase
    end

    // Used by branch logic to check equality (BEQ / BNE)
    assign zero = (result == {XLEN{1'b0}});

endmodule
