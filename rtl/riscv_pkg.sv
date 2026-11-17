// Shared enums for RV32I opcodes and ALU control signals
package riscv_pkg;

    // 7-bit base instruction opcodes
    typedef enum logic [6:0] {
        OP_R_TYPE = 7'b0110011, // Register-register operations
        OP_I_TYPE = 7'b0010011, // Immediate arithmetic and logic
        OP_LOAD   = 7'b0000011, // Data memory loads
        OP_STORE  = 7'b0100011, // Data memory stores
        OP_BRANCH = 7'b1100011, // Conditional branches
        OP_JAL    = 7'b1101111, // Jump and link
        OP_JALR   = 7'b1100111, // Jump and link register
        OP_LUI    = 7'b0110111, // Load upper immediate
        OP_AUIPC  = 7'b0010111  // Add upper immediate to PC
    } opcode_e;

    // 4-bit operation codes sent to the ALU
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_SLL  = 4'b0010,
        ALU_SLT  = 4'b0011,
        ALU_SLTU = 4'b0100,
        ALU_XOR  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_OR   = 4'b1000,
        ALU_AND  = 4'b1001
    } alu_op_e;

endpackage
