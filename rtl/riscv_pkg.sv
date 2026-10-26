package riscv_pkg;
  typedef enum logic [3:0] {
    ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR,
    ALU_SLL, ALU_SRL, ALU_SRA, ALU_SLT, ALU_SLTU
  } alu_op_t;

  typedef enum logic [2:0] {
    IMM_I, IMM_S, IMM_B, IMM_U, IMM_J
  } imm_sel_t;

  typedef enum logic [1:0] {
    WB_ALU, WB_MEM, WB_PC4, WB_IMM
  } wb_sel_t;

  localparam logic [6:0] OPCODE_R     = 7'b0110011;
  localparam logic [6:0] OPCODE_I     = 7'b0010011;
  localparam logic [6:0] OPCODE_LOAD  = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE = 7'b0100011;
  localparam logic [6:0] OPCODE_BRANCH= 7'b1100011;
  localparam logic [6:0] OPCODE_JAL   = 7'b1101111;
  localparam logic [6:0] OPCODE_JALR  = 7'b1100111;
  localparam logic [6:0] OPCODE_LUI   = 7'b0110111;
  localparam logic [6:0] OPCODE_AUIPC = 7'b0010111;
endpackage

