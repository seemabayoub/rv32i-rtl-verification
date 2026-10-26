interface riscv_if(input logic clk);
  logic reset;
  logic [31:0] instruction;
  logic [31:0] imem_address;
  logic dmem_read, dmem_write;
  logic [31:0] dmem_address, dmem_write_data, dmem_read_data;
  logic [1:0] dmem_width;
  logic dmem_unsigned;
  logic halt;
  clocking cb @(posedge clk);
    output reset, instruction, dmem_read_data;
    input imem_address, dmem_read, dmem_write, dmem_address, dmem_write_data,
          dmem_width, dmem_unsigned, halt;
  endclocking
endinterface

