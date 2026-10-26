import riscv_pkg::*;
module alu (
  input logic [31:0] a, b,
  input alu_op_t alu_op,
  output logic [31:0] result,
  output logic zero
);
  always_comb begin
    case (alu_op)
      ALU_ADD: result = a + b; ALU_SUB: result = a - b;
      ALU_AND: result = a & b; ALU_OR: result = a | b; ALU_XOR: result = a ^ b;
      ALU_SLL: result = a << b[4:0]; ALU_SRL: result = a >> b[4:0];
      ALU_SRA: result = $signed(a) >>> b[4:0];
      ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
      default: result = (a < b) ? 32'd1 : 32'd0;
    endcase
    zero = (result == 32'b0);
  end
endmodule

