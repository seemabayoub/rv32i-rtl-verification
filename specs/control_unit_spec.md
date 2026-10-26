# Control Unit Specification

## 1. Overview
The Control Unit acts as the decoding center of the RV32I core, translating raw instruction opcodes, funct3, and funct7 fields into internal datapath control signals.

## 2. Ports Description
| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `opcode_i` | Input | `7` | Instruction opcode field (`instruction[6:0]`) |
| `funct3` | Input | `3` | Secondary instruction modifier (`instruction[14:12]`) |
| `funct7_5` | Input | `1` | Bit 30 of instruction for distinguishing SUB/SRA |
| `RegWrite` | Output | `1` | Enables writing back to the Register File |
| `MemWrite` | Output | `1` | Enables writing data to Data Memory (`dmem`) |
| `ALUSrcA` | Input source selector | `1` | Selects `pc_current` (1) or `rd1` (0) for ALU operand A |
| `ALUSrcB` | Input source selector | `1` | Selects immediate `imm_ext` (1) or `rd2` (0) for ALU operand B |
| `ResultSrc` | Output | `2` | Selects writeback source (ALU, Data Memory, PC+4, or Immediate) |
| `Branch` | Output | `1` | Asserts high during conditional branch instructions |
| `Jump` | Output | `2` | Encodes jump behavior (JAL / JALR execution) |
| `ALUControl` | Output | `alu_op_e` | Specific control command routed to the ALU |

## 3. Opcode Mapping Matrix
| Instruction Type | Opcode (`instruction[6:0]`) | `funct3` | `funct7[5]` (Bit 30) | `ALUSrcA` | `ALUSrcB` | `RegWrite` | `MemWrite` | `ResultSrc` | `Branch` | `Jump` | `ALUControl` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **R-Type** (`ADD`, `SUB`, etc.) | `7'b0110011` | `3'bxxx` | `0` / `1` | `0` (`rd1`) | `0` (`rd2`) | `1` | `0` | `2'b00` (ALU) | `0` | `2'b00` | Op-dependent (`ADD`/`SUB`/`AND`/etc.) |
| **I-Type ALU** (`ADDI`, etc.) | `7'b0010011` | `3'bxxx` | `x` | `0` (`rd1`) | `1` (`imm`) | `1` | `0` | `2'b00` (ALU) | `0` | `2'b00` | Op-dependent (`ADD`/`SLT`/etc.) |
| **Load** (`LW`, `LB`, etc.) | `7'b0000011` | `3'bxxx` | `x` | `0` (`rd1`) | `1` (`imm`) | `1` | `0` | `2'b01` (Mem) | `0` | `2'b00` | `ALU_ADD` |
| **Store** (`SW`, `SB`, etc.) | `7'b0100011` | `3'bxxx` | `x` | `0` (`rd1`) | `1` (`imm`) | `0` | `1` | `2'bxx` | `0` | `2'b00` | `ALU_ADD` |
| **Branch** (`BEQ`, `BNE`, etc.) | `7'b1100011` | `3'bxxx` | `x` | `1` (`PC`) | `1` (`imm`) | `0` | `0` | `2'bxx` | `1` | `2'b00` | `ALU_ADD` |
| **JAL** | `7'b1101111` | `3'bxxx` | `x` | `1` (`PC`) | `1` (`imm`) | `1` | `0` | `2'b10` (PC+4) | `0` | `2'b01` | `ALU_ADD` |
| **JALR** | `7'b1100111` | `3'b000` | `x` | `0` (`rd1`) | `1` (`imm`) | `1` | `0` | `2'b10` (PC+4) | `0` | `2'b10` | `ALU_ADD` |
| **LUI** | `7'b0110111` | `3'bxxx` | `x` | `x` | `x` | `1` | `0` | `2'b11` (Imm) | `0` | `2'b00` | `ALU_ADD` |
| **AUIPC** | `7'b0101111` | `3'bxxx` | `x` | `1` (`PC`) | `1` (`imm`) | `1` | `0` | `2'b00` (ALU) | `0` | `2'b00` | `ALU_ADD` |
