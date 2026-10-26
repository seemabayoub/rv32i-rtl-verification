module regfile #(
    parameter XLEN     = 32,
    parameter NUM_REGS = 32
) (
    input  logic            clk,
    input  logic            reset,
    input  logic            RegWrite,
    input  logic [4:0]      read_addr1,
    input  logic [4:0]      read_addr2,
    input  logic [4:0]      write_addr,
    input  logic [XLEN-1:0] write_data,
    output logic [XLEN-1:0] read_data1,
    output logic [XLEN-1:0] read_data2
);

    logic [XLEN-1:0] regfile_array [0:NUM_REGS-1];

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_REGS; i++) begin
                regfile_array[i] <= {XLEN{1'b0}};
            end
        end
        else if (RegWrite && (write_addr != 5'b0)) begin
            regfile_array[write_addr] <= write_data;
        end
    end

    // Asynchronous reads with hardwired 0 for x0
    assign read_data1 = (read_addr1 == 5'b0) ? {XLEN{1'b0}} : regfile_array[read_addr1];
    assign read_data2 = (read_addr2 == 5'b0) ? {XLEN{1'b0}} : regfile_array[read_addr2];

endmodule
