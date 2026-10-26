module imem #(parameter int DEPTH = 1024) (
  input  logic [31:0] address,
  output logic [31:0] instruction
);
  logic [31:0] mem [0:DEPTH-1];
  always_comb begin
    if (address[31:2] < DEPTH) instruction = mem[address[31:2]];
    else                       instruction = 32'b0;
  end
endmodule

