module dmem #(parameter int DEPTH = 4096) (
  input logic clk, reset, mem_read, mem_write,
  input logic [31:0] address, write_data,
  input logic [1:0] width,
  input logic unsigned_load,
  output logic [31:0] read_data
);
  logic [7:0] mem [0:DEPTH-1];
  integer i;
  always_comb begin
    read_data = 32'b0;
    if (mem_read && address < DEPTH) begin
      case (width)
        2'd0: read_data = unsigned_load ? {24'b0, mem[address]} :
                                         {{24{mem[address][7]}}, mem[address]};
        2'd1: read_data = unsigned_load ? {16'b0, mem[address+1], mem[address]} :
                                         {{16{mem[address+1][7]}}, mem[address+1], mem[address]};
        default: read_data = {mem[address+3], mem[address+2], mem[address+1], mem[address]};
      endcase
    end
  end
  always_ff @(posedge clk) begin
    if (reset) for (i = 0; i < DEPTH; i = i + 1) mem[i] <= 8'b0;
    else if (mem_write && address < DEPTH) begin
      case (width)
        2'd0: mem[address] <= write_data[7:0];
        2'd1: begin mem[address] <= write_data[7:0]; mem[address+1] <= write_data[15:8]; end
        default: begin
          mem[address] <= write_data[7:0]; mem[address+1] <= write_data[15:8];
          mem[address+2] <= write_data[23:16]; mem[address+3] <= write_data[31:24];
        end
      endcase
    end
  end
endmodule

