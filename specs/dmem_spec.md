# Data Memory (`dmem`) Specification

## 1. Overview
The Data Memory (`dmem`) module is a synchronous-write, asynchronous-read storage block that handles byte (`lb`, `lbu`, `sb`), half-word (`lh`, `lhu`, `sh`), and word (`lw`, `sw`) memory accesses. It performs proper sign-extension or zero-extension for sub-word load operations based on the `funct3` field.

## 2. Parameters
- `XLEN`: Data width parameter set to 32 bits.
- `DEPTH`: Memory depth parameter defining total storage words (e.g., 1024 words).

## 3. Ports Description
| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | `1` | System clock signal for synchronous write operations |
| `mem_write` | Input | `1` | Write enable signal driven by the control unit |
| `funct3` | Input | `3` | Width specifier distinguishing byte, half-word, or word accesses |
| `address` | Input | `XLEN` | Effective memory address computed by the ALU |
| `write_data` | Input | `XLEN` | Data sourced from register file second read port (`rd2`) |
| `read_data` | Output | `XLEN` | Processed data routed back to the writeback mux |

## 4. Supported Access Sizes & Masking Logic
- **Word (`sw` / `lw`)**: 32-bit aligned memory access where `address[1:0] == 2'b00`. Loads and stores full 32-bit words directly.
- **Half-Word (`sh` / `lh` / `lhu`)**: 16-bit access aligned to half-word boundaries (`address[0] == 1'b0`).
  - `lh`: Loads 16-bit half-word and sign-extends bit [15] to 32 bits.
  - `lhu`: Loads 16-bit half-word and zero-extends to 32 bits.
- **Byte (`sb` / `lb` / `lbu`)**: 8-bit access indexed via byte offset bits `address[1:0]`.
  - `lb`: Loads targeted byte and sign-extends bit [7] to 32 bits.
  - `lbu`: Loads targeted byte and zero-extends to 32 bits.

## 5. Behavioral Implementation Notes
- Writes occur synchronously on the rising edge of `clk` when `mem_write` is asserted.
- Reads are combinational, allowing zero-cycle read latency from the addressed location.
