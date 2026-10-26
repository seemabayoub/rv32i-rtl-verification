module dmem #(
    parameter XLEN  = 32,
    parameter DEPTH = 256
)(
    input  logic              clk,
    input  logic              mem_write,
    input  logic [2:0]        funct3,     // From instruction to check data size
    input  logic [XLEN-1:0]   address,
    input  logic [XLEN-1:0]   write_data,
    output logic [XLEN-1:0]   read_data
);

    logic [XLEN-1:0] memory [0:DEPTH-1];
    
    // Split the address into two parts
    logic [$clog2(DEPTH)-1:0] word_addr;
    logic [1:0]               byte_offset;
    
    assign word_addr   = address[$clog2(DEPTH)+1 : 2]; // Index of the memory row
    assign byte_offset = address[1:0];                 // Byte position inside the row

    // Write data on clock edge
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b000: begin // sb (Store Byte - 8 bits)
                    case (byte_offset)
                        2'b00: memory[word_addr][7:0]   <= write_data[7:0];
                        2'b01: memory[word_addr][15:8]  <= write_data[7:0];
                        2'b10: memory[word_addr][23:16] <= write_data[7:0];
                        2'b11: memory[word_addr][31:24] <= write_data[7:0];
                    endcase
                end
                3'b001: begin // sh (Store Halfword - 16 bits)
                    case (byte_offset[1])
                        1'b0: memory[word_addr][15:0]  <= write_data[15:0];
                        1'b1: memory[word_addr][31:16] <= write_data[15:0];
                    endcase
                end
                3'b010: begin // sw (Store Word - 32 bits)
                    memory[word_addr] <= write_data;
                end
                default: ;
            endcase
        end
    end

    // Read data immediately (Combinational)
    logic [31:0] mem_word;
    assign mem_word = memory[word_addr]; // Read the full 32-bit row first

    always_comb begin
        read_data = 32'b0;
        case (funct3)
            3'b000: begin // lb (Load Byte, Sign-Extended)
                case (byte_offset)
                    2'b00: read_data = {{24{mem_word[7]}},  mem_word[7:0]};
                    2'b01: read_data = {{24{mem_word[15]}}, mem_word[15:8]};
                    2'b10: read_data = {{24{mem_word[23]}}, mem_word[23:16]};
                    2'b11: read_data = {{24{mem_word[31]}}, mem_word[31:24]};
                endcase
            end
            3'b001: begin // lh (Load Halfword, Sign-Extended)
                case (byte_offset[1])
                    1'b0: read_data = {{16{mem_word[15]}}, mem_word[15:0]};
                    1'b1: read_data = {{16{mem_word[31]}}, mem_word[31:16]};
                endcase
            end
            3'b010: read_data = mem_word; // lw (Load Word)
            
            3'b100: begin // lbu (Load Byte, Zero-Extended)
                case (byte_offset)
                    2'b00: read_data = {24'b0, mem_word[7:0]};
                    2'b01: read_data = {24'b0, mem_word[15:8]};
                    2'b10: read_data = {24'b0, mem_word[23:16]};
                    2'b11: read_data = {24'b0, mem_word[31:24]};
                endcase
            end
            3'b101: begin // lhu (Load Halfword, Zero-Extended)
                case (byte_offset[1])
                    1'b0: read_data = {16'b0, mem_word[15:0]};
                    1'b1: read_data = {16'b0, mem_word[31:16]};
                endcase
            end
            default: read_data = 32'b0;
        endcase
    end

endmodule
