import riscv_pkg::*;

// Extracts and sign-extends immediate values from 32-bit RV32I instructions
module immgen (
    input  logic [31:0] instruction,
    output logic [31:0] imm_ext
);

    opcode_e opcode;
    assign opcode = opcode_e'(instruction[6:0]);

    always_comb begin
        case (opcode)
            // I-Type (Loads, ALU immediates, JALR): sign-extend the 12-bit immediate
            OP_LOAD, OP_I_TYPE, OP_JALR: 
                imm_ext = {{20{instruction[31]}}, instruction[31:20]};
                
            // S-Type (Stores): join split immediate fields and sign-extend
            OP_STORE: 
                imm_ext = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                
            // B-Type (Branches): reorder scrambled offset bits and append 0 for 2-byte alignment
            OP_BRANCH: 
                imm_ext = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                
            // U-Type (LUI, AUIPC): place 20-bit immediate in upper bits and zero-fill lower 12 bits
            OP_LUI, OP_AUIPC: 
                imm_ext = {instruction[31:12], 12'b0};
                
            // J-Type (JAL): reorder 20-bit jump offset and append 0 for 2-byte alignment
            OP_JAL: 
                imm_ext = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
                
            default: 
                imm_ext = 32'b0;
        endcase
    end

endmodule
