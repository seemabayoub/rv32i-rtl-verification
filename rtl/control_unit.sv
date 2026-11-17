import riscv_pkg::*;

// Decodes instruction opcodes and function fields into datapath control signals
module control_unit (
    input  logic [6:0] opcode_i,
    input  logic [2:0] funct3,
    input  logic       funct7_5,    // Bit 30 of instruction (distinguishes SUB/ADD and SRA/SRL)
    
    output logic       RegWrite,    // Enables register file writeback
    output logic       MemWrite,    // Enables data memory write
    output logic       ALUSrcA,     // 0: rs1, 1: current PC (for AUIPC)
    output logic       ALUSrcB,     // 0: rs2, 1: sign-extended immediate
    output logic [1:0] ResultSrc,   // 00: ALU, 01: Data Memory, 10: PC+4, 11: Immediate
    output logic       Branch,      // Asserted for conditional branch instructions
    output logic [1:0] Jump,        // 00: None, 01: JAL, 10: JALR
    output logic [3:0] ALUControl   // Selects the ALU operation
);

    opcode_e opcode;
    assign opcode = opcode_e'(opcode_i);

    // Main decoder: drives datapath muxes and memory write enables based on opcode
    always_comb begin
        // Safe defaults to prevent inferred latches
        RegWrite  = 1'b0;
        MemWrite  = 1'b0;
        ALUSrcA   = 1'b0;
        ALUSrcB   = 1'b0;
        ResultSrc = 2'b00;
        Branch    = 1'b0;
        Jump      = 2'b00;
        
        case (opcode)
            OP_R_TYPE: begin
                RegWrite = 1'b1;
            end
            OP_I_TYPE: begin
                RegWrite = 1'b1;
                ALUSrcB  = 1'b1;
            end
            OP_LOAD: begin
                RegWrite  = 1'b1;
                ALUSrcB   = 1'b1;
                ResultSrc = 2'b01; // Route memory read data to register file
            end
            OP_STORE: begin
                MemWrite = 1'b1;
                ALUSrcB  = 1'b1;
            end
            OP_BRANCH: begin
                Branch = 1'b1;
            end
            OP_JAL: begin
                RegWrite  = 1'b1;
                Jump      = 2'b01;
                ResultSrc = 2'b10; // Save return address (PC + 4)
            end
            OP_JALR: begin
                RegWrite  = 1'b1;
                ALUSrcB   = 1'b1;
                Jump      = 2'b10;
                ResultSrc = 2'b10; // Save return address (PC + 4)
            end
            OP_LUI: begin
                RegWrite  = 1'b1;
                ResultSrc = 2'b11; // Load upper immediate directly
            end
            OP_AUIPC: begin
                RegWrite  = 1'b1;
                ALUSrcA   = 1'b1;  // Add upper immediate to current PC
                ALUSrcB   = 1'b1;
            end
            default: ; // Keep safe defaults for unsupported opcodes
        endcase
    end

    // ALU decoder: maps funct3 and funct7_5 to specific ALU operations
    always_comb begin
        ALUControl = ALU_ADD;
        
        case (opcode)
            OP_R_TYPE: begin
                case (funct3)
                    3'b000: ALUControl = funct7_5 ? ALU_SUB : ALU_ADD;
                    3'b001: ALUControl = ALU_SLL;
                    3'b010: ALUControl = ALU_SLT;
                    3'b011: ALUControl = ALU_SLTU;
                    3'b100: ALUControl = ALU_XOR;
                    3'b101: ALUControl = funct7_5 ? ALU_SRA : ALU_SRL;
                    3'b110: ALUControl = ALU_OR;
                    3'b111: ALUControl = ALU_AND;
                endcase
            end
            
            OP_I_TYPE: begin
                case (funct3)
                    3'b000: ALUControl = ALU_ADD;
                    3'b001: ALUControl = ALU_SLL;
                    3'b010: ALUControl = ALU_SLT;
                    3'b011: ALUControl = ALU_SLTU;
                    3'b100: ALUControl = ALU_XOR;
                    3'b101: ALUControl = funct7_5 ? ALU_SRA : ALU_SRL;
                    3'b110: ALUControl = ALU_OR;
                    3'b111: ALUControl = ALU_AND;
                endcase
            end
            
            OP_BRANCH: begin
                case (funct3)
                    3'b000, 3'b001: ALUControl = ALU_SUB;  // BEQ, BNE check zero flag
                    3'b100, 3'b101: ALUControl = ALU_SLT;  // BLT, BGE signed comparison
                    3'b110, 3'b111: ALUControl = ALU_SLTU; // BLTU, BGEU unsigned comparison
                    default:        ALUControl = ALU_ADD;
                endcase
            end
            
            // Loads, Stores, AUIPC, JAL, and JALR use ADD for effective address calculation
            default: ALUControl = ALU_ADD; 
        endcase
    end

endmodule
