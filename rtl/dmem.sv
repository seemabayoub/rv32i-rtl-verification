// Byte-addressable data memory supporting byte, halfword, and word accesses
module dmem #(
    parameter XLEN  = 32,
    parameter DEPTH = 256
)(
    input  logic              clk,
    input  logic              mem_write,
    input  logic [2:0]        funct3,     // Encodes access width and sign extension (LB/LH/LW/LBU/LHU, SB/SH/SW)
    input  logic [XLEN-1:0]   address,
    input  logic [XLEN-1:0]   write_data,
    output logic [XLEN-1:0]   read_data
);

    logic [XLEN-1:0] memory [0:DEPTH-1];

    // Initialize memory to zero so reads before writes do not return X in simulation
    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            memory[i] = '0;
        end
    end
    
    // Split byte address into 32-bit word index and byte offset within the word
    logic [$clog2(DEPTH)-1:0] word_addr;
    logic [1:0]               byte_offset;
    
    assign word_addr   = address[$clog2(DEPTH)+1 : 2];
    assign byte_offset = address[1:0];

    // Synchronous write on rising clock edge
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB: write single byte based on byte offset
                    case (byte_offset)
                        2'b00: memory[word_addr][7:0]   <= write_data[7:0];
                        2'b01: memory[word_addr][15:8]  <= write_data[7:0];
                        2'b10: memory[word_addr][23:16] <= write_data[7:0];
                        2'b11: memory[word_addr][31:24] <= write_data[7:0];
                    endcase
                end
                3'b001: begin // SH: write lower or upper 16-bit halfword
                    case (byte_offset[1])
                        1'b0: memory[word_addr][15:0]  <= write_data[15:0];
                        1'b1: memory[word_addr][31:16] <= write_data[15:0];
                    endcase
                end
                3'b010: begin // SW: write full 32-bit word
                    memory[word_addr] <= write_data;
                end
                default: ;
            endcase
        end
    end

    // Asynchronous combinational read for single-cycle execution
    logic [31:0] mem_word;
    assign mem_word = memory[word_addr];

    always_comb begin
        read_data = 32'b0;
        case (funct3)
            3'b000: begin // LB: sign-extend selected byte
                case (byte_offset)
                    2'b00: read_data = {{24{mem_word[7]}},  mem_word[7:0]};
                    2'b01: read_data = {{24{mem_word[15]}}, mem_word[15:8]};
                    2'b10: read_data = {{24{mem_word[23]}}, mem_word[23:16]};
                    2'b11: read_data = {{24{mem_word[31]}}, mem_word[31:24]};
                endcase
            end
            3'b001: begin // LH: sign-extend selected halfword
                case (byte_offset[1])
                    1'b0: read_data = {{16{mem_word[15]}}, mem_word[15:0]};
                    1'b1: read_data = {{16{mem_word[31]}}, mem_word[31:16]};
                endcase
            end
            3'b010: read_data = mem_word; // LW: return full 32-bit word
            
            3'b100: begin // LBU: zero-extend selected byte
                case (byte_offset)
                    2'b00: read_data = {24'b0, mem_word[7:0]};
                    2'b01: read_data = {24'b0, mem_word[15:8]};
                    2'b10: read_data = {24'b0, mem_word[23:16]};
                    2'b11: read_data = {24'b0, mem_word[31:24]};
                endcase
            end
            3'b101: begin // LHU: zero-extend selected halfword
                case (byte_offset[1])
                    1'b0: read_data = {16'b0, mem_word[15:0]};
                    1'b1: read_data = {16'b0, mem_word[31:16]};
                endcase
            end
            default: read_data = 32'b0;
        endcase
    end

endmodule
