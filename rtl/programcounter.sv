// Program Counter register that updates on each clock cycle
module programcounter #(
    parameter XLEN = 32
)(
    input  logic            clk,
    input  logic            reset,
    input  logic            stall,      // Keeps current PC value when high
    input  logic [XLEN-1:0] pc_next,
    output logic [XLEN-1:0] pc_current
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            pc_current <= {XLEN{1'b0}}; // Start execution from address 0x0000_0000
        else if (stall)
            pc_current <= pc_current;   // Freeze PC during a stall
        else
            pc_current <= pc_next;      // Advance to the next instruction address
    end

endmodule
