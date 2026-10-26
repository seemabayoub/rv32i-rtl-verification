class riscv_trans;
  rand bit [31:0] instruction;
  rand bit [31:0] expected_result;
  constraint supported_opcode { instruction[6:0] inside {
    7'b0110011, 7'b0010011, 7'b0000011, 7'b0100011, 7'b1100011,
    7'b1101111, 7'b1100111, 7'b0110111, 7'b0010111}; }
  function void pack_instruction(ref bit [31:0] packed);
    packed = instruction;
  endfunction
endclass

