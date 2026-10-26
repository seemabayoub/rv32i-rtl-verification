# Instruction Memory (`imem`) Specification

## 1. Overview
The Instruction Memory (`imem`) module acts as the read-only instruction storage array for the RV32I processor core. It provides asynchronous, combinational read access indexed by the current Program Counter (`pc_current`) address to fetch 32-bit instructions.

## 2. Parameters
- `XLEN`: Data width parameter set to 32 bits.
- `DEPTH`: Memory depth parameter defining the total number of instruction words stored (e.g., 1024 words).
- `INIT_FILE`: Optional initialization parameter pointing to a hex file containing compiled machine code instructions.

## 3. Ports Description
| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `address` | Input | `XLEN` | Current PC address provided by the program counter (`pc_current`) |
| `instruction` | Output | `XLEN` | Fetched 32-bit machine instruction routed to the decode stage |

## 4. Behavioral Implementation & Addressing Logic
- Implemented as a word-addressed ROM array.
- Since RV32I instructions are word-aligned, the lower two bits of the byte address (`address[1:0]`) are ignored or constrained to zero, and the memory array is indexed using `address[$clog2(DEPTH)+1 : 2]`.
- Provides zero-cycle combinational read latency so that instructions are available within the same clock cycle as the PC update.
