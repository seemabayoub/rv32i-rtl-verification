import riscv_pkg::*;

module control_unit (
    input  logic [6:0] opcode_i,
    input  logic [2:0] funct3,
    input  logic       funct7_5,    // Bit 30 of instruction (used for SUB/SRA)
    
    output logic       RegWrite,    // 1: Write to RegFile
    output logic       MemWrite,    // 1: Write to Data Memory
    output logic       ALUSrcA,     // 0: Use rs1, 1: Use PC (for AUIPC)
    output logic       ALUSrcB,     // 0: Use rs2, 1: Use Immediate
    output logic [1:0] ResultSrc,   // 00: ALU, 01: DMem, 10: PC+4, 11: Immediate
    output logic       Branch,      // 1: Branch instruction
    output logic [1:0] Jump,        // 00: No jump, 01: JAL, 10: JALR
    output logic [3:0] ALUControl   // ALU operation selector
);

    opcode_e opcode;
    assign opcode = opcode_e'(opcode_i);

    // Main Decoder: Generates signals for multiplexers and memory based on opcode
    always_comb begin
        // Default values to prevent hardware latches
        RegWrite  = 1'b0;
        MemWrite  = 1'b0;
        ALUSrcA   = 1'b0;
        ALUSrcB   = 1'b0;
        ResultSrc = 2'b00;
        Branch    = 1'b0;
        Jump      = 2'b00;
        
        case (opcode)
            OP_R_TYPE: begin // R-Type (add, sub, and, etc.)
                RegWrite = 1'b1;
            end
            OP_I_TYPE: begin // I-Type (addi, slli, etc.)
                RegWrite = 1'b1;
                ALUSrcB  = 1'b1;
            end
            OP_LOAD: begin // Loads (lw, lb, lh, etc.)
                RegWrite  = 1'b1;
                ALUSrcB   = 1'b1;
                ResultSrc = 2'b01;
            end
            OP_STORE: begin // Stores (sw, sb, sh)
                MemWrite = 1'b1;
                ALUSrcB  = 1'b1;
            end
            OP_BRANCH: begin // Branches (beq, bne, blt, etc.)
                Branch = 1'b1;
            end
            OP_JAL: begin // JAL
                RegWrite  = 1'b1;
                Jump      = 2'b01;
                ResultSrc = 2'b10;
            end
            OP_JALR: begin // JALR
                RegWrite  = 1'b1;
                ALUSrcB   = 1'b1;
                Jump      = 2'b10;
                ResultSrc = 2'b10;
            end
            OP_LUI: begin // LUI
                RegWrite  = 1'b1;
                ResultSrc = 2'b11;
            end
            OP_AUIPC: begin // AUIPC
                RegWrite  = 1'b1;
                ALUSrcA   = 1'b1; // Use PC
                ALUSrcB   = 1'b1; // Use Immediate
            end
            default: ; // Do nothing for invalid opcodes
        endcase
    end

    // ALU Decoder: Decides exactly what math operation the ALU should perform
    always_comb begin
        ALUControl = 4'b0000; // Default is ADD
        
        case (opcode)
            OP_R_TYPE: begin // R-Type
                case (funct3)
                    3'b000: ALUControl = funct7_5 ? ALU_SUB : ALU_ADD; // SUB or ADD
                    3'b001: ALUControl = ALU_SLL; // SLL
                    3'b010: ALUControl = ALU_SLT; // SLT
                    3'b011: ALUControl = ALU_SLTU; // SLTU
                    3'b100: ALUControl = ALU_XOR; // XOR
                    3'b101: ALUControl = funct7_5 ? ALU_SRA : ALU_SRL; // SRA or SRL
                    3'b110: ALUControl = ALU_OR; // OR
                    3'b111: ALUControl = ALU_AND; // AND
                endcase
            end
            
            OP_I_TYPE: begin // I-Type
                case (funct3)
                    3'b000: ALUControl = ALU_ADD; // ADD (addi)
                    3'b001: ALUControl = ALU_SLL; // SLL (slli)
                    3'b010: ALUControl = ALU_SLT; // SLT (slti)
                    3'b011: ALUControl = ALU_SLTU; // SLTU (sltiu)
                    3'b100: ALUControl = ALU_XOR; // XOR (xori)
                    3'b101: ALUControl = funct7_5 ? ALU_SRA : ALU_SRL; // SRAI or SRLI
                    3'b110: ALUControl = ALU_OR; // OR (ori)
                    3'b111: ALUControl = ALU_AND; // AND (andi)
                endcase
            end
            
            OP_BRANCH: begin // Branches
                case (funct3)
                    3'b000, 3'b001: ALUControl = ALU_SUB; // beq, bne use SUB
                    3'b100, 3'b101: ALUControl = ALU_SLT; // blt, bge use SLT
                    3'b110, 3'b111: ALUControl = ALU_SLTU; // bltu, bgeu use SLTU
                    default: ALUControl = ALU_ADD;
                endcase
            end
            
            // For Loads, Stores, AUIPC, LUI, JAL, JALR
            // The default ALUControl (ADD) is used to calculate addresses
            default: ALUControl = ALU_ADD; 
        endcase
    end

endmodule
