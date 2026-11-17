import riscv_pkg::*;

// Top-level 32-bit single-cycle RV32I processor core
module riscv_core #(
    parameter XLEN = 32
)(
    input logic clk,
    input logic reset
);

    // Program counter signals
    logic [XLEN-1:0] pc_current, pc_next;
    
    // Instruction and data memory buses
    logic [XLEN-1:0] instruction;
    logic [XLEN-1:0] dmem_read_data;
    
    // Register file read and writeback buses
    logic [XLEN-1:0] rd1, rd2, result_mux_out;
    
    // Immediate generator and ALU signals
    logic [XLEN-1:0] imm_ext;
    logic [XLEN-1:0] alu_src_a, alu_src_b, alu_result;
    logic            alu_zero;
    
    // Control unit outputs and branch condition flag
    logic        RegWrite, MemWrite, ALUSrcA, ALUSrcB, Branch;
    logic [1:0]  ResultSrc, Jump;
    alu_op_e     ALUControl;
    logic        take_branch;

    // Instruction field decode (continuous assignments, always follow 'instruction')
    logic [6:0] opcode_wire;
    logic [2:0] funct3;
    logic       funct7_5;
    logic [4:0] rs1, rs2, rd;

    assign opcode_wire = instruction[6:0];
    assign funct3      = instruction[14:12];
    assign funct7_5    = instruction[30];
    assign rs1         = instruction[19:15];
    assign rs2         = instruction[24:20];
    assign rd          = instruction[11:7];

    // Program Counter register
    programcounter #(XLEN) pc_module (
        .clk(clk),
        .reset(reset),
        .stall(1'b0), // Single-cycle core executes one instruction per cycle without stalling
        .pc_next(pc_next),
        .pc_current(pc_current)
    );

    // Instruction Memory
    imem #(XLEN, 256) imem_module (
        .address(pc_current),
        .instruction(instruction)
    );

    // 32x32 General-Purpose Register File
    regfile #(XLEN, 32) regfile_module (
        .clk(clk),
        .reset(reset),
        .RegWrite(RegWrite),
        .read_addr1(rs1),
        .read_addr2(rs2),
        .write_addr(rd),
        .write_data(result_mux_out),
        .read_data1(rd1),
        .read_data2(rd2)
    );

    // Immediate Generator
    immgen immgen_module (
        .instruction(instruction),
        .imm_ext(imm_ext)
    );

    // Main and ALU Control Unit
    control_unit control_module (
        .opcode_i(opcode_wire),
        .funct3(funct3),
        .funct7_5(funct7_5),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ResultSrc(ResultSrc),
        .Branch(Branch),
        .Jump(Jump),
        .ALUControl(ALUControl)
    );

    // Arithmetic Logic Unit
    alu #(XLEN) alu_module (
        .a(alu_src_a),
        .b(alu_src_b),
        .alu_ctrl_i(ALUControl),
        .result(alu_result),
        .zero(alu_zero)
    );

    // Byte-Addressable Data Memory
    dmem #(XLEN, 256) dmem_module (
        .clk(clk),
        .mem_write(MemWrite),
        .funct3(funct3),
        .address(alu_result),
        .write_data(rd2),
        .read_data(dmem_read_data)
    );

    // Operand selection muxes (PC vs rs1 for AUIPC, immediate vs rs2 for I/S/B/U types)
    assign alu_src_a = ALUSrcA ? pc_current : rd1;
    assign alu_src_b = ALUSrcB ? imm_ext    : rd2;

    // Writeback multiplexer selecting what gets saved into rd
    always_comb begin
        case (ResultSrc)
            2'b00:   result_mux_out = alu_result;
            2'b01:   result_mux_out = dmem_read_data;
            2'b10:   result_mux_out = pc_current + 32'd4; // Return address for JAL/JALR
            2'b11:   result_mux_out = imm_ext;            // Upper immediate for LUI
            default: result_mux_out = alu_result;
        endcase
    end

    // Evaluate branch condition based on ALU flags and funct3
    always_comb begin
        take_branch = 1'b0;
        if (Branch) begin
            case (funct3)
                3'b000:  take_branch = alu_zero;      // BEQ
                3'b001:  take_branch = !alu_zero;     // BNE
                3'b100:  take_branch = alu_result[0]; // BLT
                3'b101:  take_branch = !alu_result[0];// BGE
                3'b110:  take_branch = alu_result[0]; // BLTU
                3'b111:  take_branch = !alu_result[0];// BGEU
                default: take_branch = 1'b0;
            endcase
        end
    end

    // Next PC calculation logic
    always_comb begin
        if (Jump == 2'b10) begin
            pc_next = alu_result & 32'hFFFFFFFE; // JALR target (clear lowest bit per RISC-V spec)
        end 
        else if (Jump == 2'b01 || take_branch) begin
            pc_next = pc_current + imm_ext;      // JAL or taken branch target
        end 
        else begin
            pc_next = pc_current + 32'd4;        // Sequential next instruction
        end
    end

endmodule
