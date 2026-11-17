`ifndef RISCV_TRANS_SV
`define RISCV_TRANS_SV

// Transaction class representing a single RV32I instruction and its observed DUT outputs
class riscv_trans;
    // Randomized instruction fields
    rand bit [6:0]         opcode;
    rand bit [4:0]         rs1;
    rand bit [4:0]         rs2;
    rand bit [4:0]         rd;
    rand bit [2:0]         funct3;
    rand bit [6:0]         funct7;
    rand bit signed [31:0] imm;          // Signed immediate so negative offsets randomize properly

    bit        directed = 0;             // 1: use fixed offsets/addresses for deterministic tests
    int        jalr_t1  = 8;             // Absolute JALR target (pc_addr + 8, used with rs1 = x0)
    int        jalr_t2  = 12;            // Absolute JALR target (pc_addr + 12, used with rs1 = x0)
    bit [31:0] pc_addr  = 0;             // Byte address of this instruction in imem
    string     name     = "RANDOM";
    bit [31:0] instruction;

    // Actual DUT signals captured by the monitor (4-state logic to detect X/Z)
    logic [31:0] actual_pc;
    logic [31:0] actual_pc_next;
    logic [31:0] actual_instruction;
    logic [31:0] actual_alu_result;
    logic        actual_reg_write_en;
    logic [4:0]  actual_reg_write_addr;
    logic [31:0] actual_reg_write_data;
    logic        actual_mem_write_en;
    logic [31:0] actual_mem_addr;
    logic [31:0] actual_mem_write_data;

    // Sets instruction PC and updates valid forward JALR targets before randomize()
    function void set_pc(bit [31:0] addr);
        pc_addr = addr;
        jalr_t1 = int'(addr) + 8;
        jalr_t2 = int'(addr) + 12;
    endfunction

    // Constrain opcode to the 9 base RV32I instruction formats
    constraint op_type_c {
        opcode inside {
            7'b0110011, // R-Type
            7'b0010011, // I-Type ALU
            7'b0000011, // Loads
            7'b0100011, // Stores
            7'b1100011, // Branches
            7'b1101111, // JAL
            7'b1100111, // JALR
            7'b0110111, // LUI
            7'b0010111  // AUIPC
        };
    }

    // Keep funct7 zero for instruction formats that do not use it
    constraint f7_default_c {
        (opcode != 7'b0110011 &&
         !(opcode == 7'b0010011 && (funct3 == 3'b001 || funct3 == 3'b101)))
            -> (funct7 == 7'b0000000);
    }

    // R-Type allows funct7 = 0100000 only for SUB (000) and SRA (101)
    constraint r_type_c {
        if (opcode == 7'b0110011) {
            if (funct3 == 3'b000 || funct3 == 3'b101) {
                funct7 inside {7'b0000000, 7'b0100000};
            } else {
                funct7 == 7'b0000000;
            }
        }
    }

    // I-Type shift instructions encode shift direction in upper immediate bits (imm[11:5])
    constraint i_type_c {
        if (opcode == 7'b0010011) {
            if (funct3 == 3'b001) {
                funct7 == 7'b0000000;
                imm[11:5] == funct7;
            } else if (funct3 == 3'b101) {
                funct7 inside {7'b0000000, 7'b0100000};
                imm[11:5] == funct7;
            } else {
                imm inside {[-2048:2047]};
            }
        }
    }

    // Base loads off x0 into initialized data memory range [0:63] with proper alignment
    constraint load_c {
        if (opcode == 7'b0000011) {
            funct3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101};
            rs1 == 5'd0;
            if (directed) { imm == 16; } else { imm inside {[0:63]}; }
            if (funct3 == 3'b010) { imm[1:0] == 2'b00; }                 // Word-aligned for LW
            if (funct3 == 3'b001 || funct3 == 3'b101) { imm[0] == 1'b0; } // Halfword-aligned for LH/LHU
        }
    }

    // Base stores off x0 into data memory range [0:63] with proper alignment
    constraint store_c {
        if (opcode == 7'b0100011) {
            funct3 inside {3'b000, 3'b001, 3'b010};
            rs1 == 5'd0;
            if (directed) { imm == 16; } else { imm inside {[0:63]}; }
            if (funct3 == 3'b010) { imm[1:0] == 2'b00; } // Word-aligned for SW
            if (funct3 == 3'b001) { imm[0] == 1'b0; }    // Halfword-aligned for SH
        }
    }

    // Restrict branches to short forward offsets (+8 or +12 bytes) to prevent infinite loops
    constraint branch_c {
        if (opcode == 7'b1100011) {
            funct3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111};
            if (directed) { imm == 8; } else { imm inside {8, 12}; }
        }
    }

    // Restrict JAL to short forward offsets (+8 or +12 bytes)
    constraint jal_c {
        if (opcode == 7'b1101111) {
            if (directed) { imm == 8; } else { imm inside {8, 12}; }
        }
    }

    // Use x0 + absolute target address for JALR to guarantee valid forward jumps
    constraint jalr_c {
        if (opcode == 7'b1100111) {
            funct3 == 3'b000;
            rs1    == 5'd0;
            if (directed) { imm == jalr_t1; } else { imm inside {jalr_t1, jalr_t2}; }
        }
    }

    // Zero lower 12 bits for U-Type immediates (LUI and AUIPC)
    constraint u_type_c {
        if (opcode == 7'b0110111 || opcode == 7'b0010111) {
            imm[11:0] == 12'b0;
        }
    }

    // Packs randomized fields into a 32-bit RV32I machine instruction word
    function void build();
        case (opcode)
            7'b0110011: instruction = {funct7, rs2, rs1, funct3, rd, opcode};
            7'b0010011,
            7'b0000011,
            7'b1100111: instruction = {imm[11:0], rs1, funct3, rd, opcode};
            7'b0100011: instruction = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
            7'b1100011: instruction = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
            7'b1101111: instruction = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
            7'b0110111,
            7'b0010111: instruction = {imm[31:12], rd, opcode};
            default:    instruction = 32'h00000013;
        endcase
    endfunction

    function void post_randomize();
        build();
    endfunction

    // Builds an ADDI x0, x0, 0 (NOP) instruction
    function void make_nop();
        opcode = 7'b0010011; rd = 0; rs1 = 0; rs2 = 0; funct3 = 0; funct7 = 0; imm = 0;
        name = "NOP";
        build();
    endfunction

    // Prints decoded instruction fields for debug tracing
    function void display(string tag = "TRANS");
        $display("[%s] %s pc=0x%08h instr=0x%08h op=%07b rd=%0d rs1=%0d rs2=%0d f3=%03b f7=%07b imm=%0d",
                 tag, name, pc_addr, instruction, opcode, rd, rs1, rs2, funct3, funct7, imm);
    endfunction
endclass

`endif
