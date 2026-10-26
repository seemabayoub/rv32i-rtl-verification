# Core Integration (`riscv_core`) Specification

## 1. Overview
The `riscv_core` module serves as the top-level integration wrapper for the single-cycle RV32I processor architecture. It instantiates and interconnects all core datapath and control components including the Program Counter, Instruction Memory, Register File, Immediate Generator, Control Unit, ALU, and Data Memory.

## 2. Ports Description
| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | `1` | System clock signal driving synchronous sequential elements |
| `reset` | Input | `1` | Active-high synchronous/asynchronous reset clearing PC and register states |

## 3. Internal Submodules & Datapath Wiring
- **Program Counter (`programcounter`)**: Manages instruction fetch addresses (`pc_current`). Computes sequential next address (`PC + 4`) or branch/jump target addresses based on control signals from the Control Unit and ALU condition flags.
- **Instruction Memory (`imem`)**: Asynchronously looks up 32-bit machine code instructions indexed by `pc_current`.
- **Register File (`regfile`)**: Dual-read, single-write 32x32 register bank where register `x0` is hardwired to `32'h00000000`. Sources source operands `rs1` and `rs2` and writes back data based on `RegWrite`.
- **Immediate Generator (`immgen`)**: Extracts and sign-extends immediate values from instructions across I, S, B, U, and J formats.
- **Control Unit (`control_unit`)**: Decodes instruction opcodes, `funct3`, and `funct7` fields to generate datapath mux selects and enable flags (`ALUSrcA`, `ALUSrcB`, `ResultSrc`, `Branch`, `Jump`, `MemWrite`, `RegWrite`, `ALUControl`).
- **Arithmetic Logic Unit (`alu`)**: Executes arithmetic, logical, and shift operations on operands selected by `ALUSrcA` and `ALUSrcB`, providing output results and `zero` flags.
- **Data Memory (`dmem`)**: Synchronous data storage handling word, half-word, and byte loads/stores based on effective addresses computed by the ALU.

## 4. Top-Level Datapath Flow
1. **Fetch**: PC supplies address to Instruction Memory.
2. **Decode**: Instruction is routed to Control Unit, Register File address selectors, and Immediate Generator.
3. **Execute**: Register values and/or immediates are fed into the ALU via multiplexers controlled by `ALUSrcA` and `ALUSrcB`.
4. **Memory / Writeback**: Results are stored back into the Register File or Data Memory depending on `ResultSrc`, `MemWrite`, and `RegWrite` assertions.
