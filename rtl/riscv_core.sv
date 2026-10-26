import riscv_pkg::*;

module riscv_core #(
    parameter XLEN = 32
)(
    input logic clk,
    input logic reset
);

    // Wires for PC
    logic [XLEN-1:0] pc_current, pc_next;
    
    // Wires for memory and instructions
    logic [XLEN-1:0] instruction;
    logic [XLEN-1:0] dmem_read_data;
    
    // Wires for register file
    logic [XLEN-1:0] rd1, rd2, result_mux_out;
    
    // Wires for ALU and immediate values
    logic [XLEN-1:0] imm_ext;
    logic [XLEN-1:0] alu_src_a, alu_src_b, alu_result;
    logic            alu_zero;
    
    // Wires for control signals
    logic        RegWrite, MemWrite, ALUSrcA, ALUSrcB, Branch;
    logic [1:0]  ResultSrc, Jump;
    alu_op_e     ALUControl;
    logic        take_branch;

    // Decode instruction parts
    logic [6:0] opcode_wire = instruction[6:0];
    logic [2:0] funct3      = instruction[14:12];
    logic       funct7_5    = instruction[30];
    logic [4:0] rs1         = instruction[19:15];
    logic [4:0] rs2         = instruction[24:20];
    logic [4:0] rd          = instruction[11:7];

    // Program Counter
    programcounter #(XLEN) pc_module (
        .clk(clk),
        .reset(reset),
        .stall(1'b0), // No stall needed yet
        .pc_next(pc_next),
        .pc_current(pc_current)
    );

    // Instruction Memory
    imem #(XLEN, 256) imem_module (
        .address(pc_current),
        .instruction(instruction)
    );

    // Register File
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

    // Control Unit
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

    // ALU
    alu #(XLEN) alu_module (
        .a(alu_src_a),
        .b(alu_src_b),
        .alu_ctrl_i(ALUControl),
        .result(alu_result),
        .zero(alu_zero)
    );

    // Data Memory
    dmem #(XLEN, 256) dmem_module (
        .clk(clk),
        .mem_write(MemWrite),
        .funct3(funct3),
        .address(alu_result),
        .write_data(rd2),
        .read_data(dmem_read_data)
    );

    // Select inputs for ALU
    assign alu_src_a = ALUSrcA ? pc_current : rd1;
    assign alu_src_b = ALUSrcB ? imm_ext    : rd2;

    // Select data to save in register file
    always_comb begin
        case (ResultSrc)
            2'b00: result_mux_out = alu_result;
            2'b01: result_mux_out = dmem_read_data;
            2'b10: result_mux_out = pc_current + 32'd4; // Save return address
            2'b11: result_mux_out = imm_ext;            // Save immediate
            default: result_mux_out = alu_result;
        endcase
    end

    // Check if branch should be taken
    always_comb begin
        take_branch = 1'b0;
        if (Branch) begin
            case (funct3)
                3'b000: take_branch = alu_zero;       // Equal
                3'b001: take_branch = !alu_zero;      // Not equal
                3'b100: take_branch = alu_result[0];  // Less than
                3'b101: take_branch = !alu_result[0]; // Greater or equal
                3'b110: take_branch = alu_result[0];  // Less than unsigned
                3'b111: take_branch = !alu_result[0]; // Greater or equal unsigned
                default: take_branch = 1'b0;
            endcase
        end
    end

    // Calculate next PC address
    always_comb begin
        if (Jump == 2'b10) begin
            pc_next = alu_result & 32'hFFFFFFFE; // JALR
        end 
        else if (Jump == 2'b01 || take_branch) begin
            pc_next = pc_current + imm_ext; // JAL or Branch
        end 
        else begin
            pc_next = pc_current + 32'd4; // Normal next instruction
        end
    end

endmodule
