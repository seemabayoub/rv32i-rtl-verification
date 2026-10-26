module programcounter #(
    parameter XLEN = 32 //For 32 bit 
)(
    input logic clk,
    input logic reset,
    input logic stall, // For hold state
    input logic [XLEN-1:0] pc_next,
    output logic [XLEN-1:0] pc_current
);

always_ff @(posedge clk or posedge reset) begin
    if (reset)
        pc_current <= {XLEN{1'b0}}; 
    else if (stall)
        pc_current <= pc_current;   // hold 
    else
        pc_current <= pc_next;
end
endmodule
