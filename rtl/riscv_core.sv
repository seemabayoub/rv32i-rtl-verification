import riscv_pkg::*;
module riscv_core (
  input logic clk, reset,
  output logic [31:0] imem_address,
  input logic [31:0] instruction,
  output logic dmem_read, dmem_write,
  output logic [31:0] dmem_address, dmem_write_data,
  output logic [1:0] dmem_width,
  output logic dmem_unsigned,
  input logic [31:0] dmem_read_data,
  output logic halt
);
  logic [31:0] pc, next_pc, imm, rs1_data, rs2_data, alu_b, alu_result, wb_data;
  logic [31:0] pc4;
  logic reg_write, mem_read, mem_write, branch, jump, alu_src, unsigned_load;
  logic [1:0] wb_sel;
  logic [2:0] imm_sel;
  logic alu_zero;
  alu_op_t alu_op;
  assign imem_address = pc; assign pc4 = pc + 32'd4;
  assign dmem_read = mem_read; assign dmem_write = mem_write;
  assign dmem_address = alu_result; assign dmem_write_data = rs2_data;
  assign dmem_width = dmem_width_i; assign dmem_unsigned = unsigned_load;
  assign halt = 1'b0;

  logic [1:0] dmem_width_i;
  programcounter pc_reg(.clk, .reset, .next_pc, .pc);
  control_unit decoder(.opcode(instruction[6:0]), .funct3(instruction[14:12]),
    .funct7_bit(instruction[30]), .reg_write, .mem_read, .mem_write, .branch,
    .jump, .alu_src, .mem_width(dmem_width_i), .unsigned_load, .imm_sel,
    .wb_sel, .alu_op);
  immgen immediate_gen(.instruction, .imm_sel, .immediate(imm));
  regfile registers(.clk, .reset, .write_enable(reg_write), .rs1(instruction[19:15]),
    .rs2(instruction[24:20]), .rd(instruction[11:7]), .write_data(wb_data),
    .read_data1(rs1_data), .read_data2(rs2_data));
  assign alu_b = alu_src ? imm : rs2_data;
  alu execute(.a((instruction[6:0] == OPCODE_AUIPC) ? pc : rs1_data),
    .b(alu_b), .alu_op, .result(alu_result), .zero(alu_zero));
  always_comb begin
    case (wb_sel)
      WB_MEM: wb_data = dmem_read_data;
      WB_PC4: wb_data = pc4;
      WB_IMM: wb_data = imm;
      default: wb_data = alu_result;
    endcase
    next_pc = pc4;
    if (branch && alu_zero) next_pc = pc + imm;
    if (jump) next_pc = (instruction[6:0] == OPCODE_JALR) ?
                         ((rs1_data + imm) & 32'hffff_fffe) : pc + imm;
  end
endmodule

