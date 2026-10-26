import riscv_pkg::*;
module control_unit (
  input logic [6:0] opcode,
  input logic [2:0] funct3,
  input logic funct7_bit,
  output logic reg_write, mem_read, mem_write, branch, jump, alu_src,
  output logic [1:0] mem_width,
  output logic unsigned_load,
  output logic [2:0] imm_sel,
  output logic [1:0] wb_sel,
  output alu_op_t alu_op
);
  always_comb begin
    {reg_write, mem_read, mem_write, branch, jump, alu_src, unsigned_load} = 7'b0;
    mem_width = 2'd2; imm_sel = IMM_I; wb_sel = WB_ALU; alu_op = ALU_ADD;
    case (opcode)
      OPCODE_R: begin
        reg_write = 1'b1;
        case (funct3)
          3'b000: alu_op = funct7_bit ? ALU_SUB : ALU_ADD;
          3'b001: alu_op = ALU_SLL;
          3'b010: alu_op = ALU_SLT;
          3'b011: alu_op = ALU_SLTU;
          3'b100: alu_op = ALU_XOR;
          3'b101: alu_op = funct7_bit ? ALU_SRA : ALU_SRL;
          3'b110: alu_op = ALU_OR;
          default: alu_op = ALU_AND;
        endcase
      end
      OPCODE_I: begin reg_write = 1'b1; alu_src = 1'b1; end
      OPCODE_LOAD: begin reg_write = 1'b1; mem_read = 1'b1; alu_src = 1'b1; wb_sel = WB_MEM; end
      OPCODE_STORE: begin mem_write = 1'b1; alu_src = 1'b1; imm_sel = IMM_S; end
      OPCODE_BRANCH: begin branch = 1'b1; imm_sel = IMM_B; alu_op = ALU_SUB; end
      OPCODE_JAL: begin reg_write = 1'b1; jump = 1'b1; imm_sel = IMM_J; wb_sel = WB_PC4; end
      OPCODE_JALR: begin reg_write = 1'b1; jump = 1'b1; alu_src = 1'b1; wb_sel = WB_PC4; end
      OPCODE_LUI: begin reg_write = 1'b1; imm_sel = IMM_U; wb_sel = WB_IMM; end
      OPCODE_AUIPC: begin reg_write = 1'b1; imm_sel = IMM_U; alu_src = 1'b1; end
      default: ;
    endcase
    if (opcode == OPCODE_LOAD || opcode == OPCODE_STORE) begin
      case (funct3)
        3'b000: mem_width = 2'd0;
        3'b001: mem_width = 2'd1;
        3'b010: mem_width = 2'd2;
        3'b100: begin mem_width = 2'd0; unsigned_load = 1'b1; end
        3'b101: begin mem_width = 2'd1; unsigned_load = 1'b1; end
        default: ;
      endcase
    end
  end
endmodule

