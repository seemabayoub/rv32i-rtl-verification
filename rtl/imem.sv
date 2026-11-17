// Read-only instruction memory storing 32-bit machine code words
module imem #(
    parameter XLEN  = 32,
    parameter DEPTH = 256 // Total number of 32-bit instruction words
)(
    input  logic [XLEN-1:0] address,
    output logic [XLEN-1:0] instruction
);

    logic [XLEN-1:0] memory [0:DEPTH-1];

    // Load initial program hex file if available in simulation directory
    initial begin
        $readmemh("program.mem", memory);
    end
    
    // Drop the bottom 2 byte-offset bits to read word-aligned instructions
    assign instruction = memory[address[$clog2(DEPTH)+1 : 2]];

endmodule
