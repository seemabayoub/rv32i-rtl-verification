module imem #(
    parameter XLEN  = 32,
    parameter DEPTH = 256 // Total Locations in Memory
)(
    input logic  [XLEN-1:0] address,
    output logic [XLEN-1:0] instruction
);

    logic [XLEN-1:0] memory [0:DEPTH-1];
    initial begin
        $readmemh("program.mem", memory);
    end
    
    // Autocalculate exact bits needed for word-aligned memory access and store it in imem
    assign instruction = memory[address[$clog2(DEPTH)+1 : 2]];

endmodule
