# ALU (Arithmetic Logic Unit) Specification

## 1. Overview
The ALU is a combinational hardware block responsible for executing arithmetic, logical, and shift operations mandated by the RV32I instruction set architecture. It operates on two data operands and produces a calculated result along with status flags like the zero indicator.

## 2. Parameters
- `XLEN`: Data width parameter set to 32 bits for RV32I architecture compliance.

## 3. Ports Description
| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `a` | Input | `XLEN` | First data operand (sourced from register file or PC) |
| `b` | Input | `XLEN` | Second data operand (sourced from register file or immediate generator) |
| `alu_ctrl_i` | Input | `alu_op_e` | Operation control enum signal routed from the control unit |
| `result` | Output | `XLEN` | Final computed output data |
| `zero` | Output | `1` | High status flag if `result == 32'h00000000`, used for branch condition evaluation |

## 4. Supported Operations & Decoding Logic
- **`ALU_ADD`**: Performs integer addition where `result = a + b`. Used by arithmetic instructions (`add`, `addi`), load/store effective address calculations, and branch target calculations.
- **`ALU_SUB`**: Performs integer subtraction where `result = a - b`. Used by subtraction operations (`sub`) and branch condition comparisons.
- **`ALU_SLL`**: Shift left logical where `result = a << b[4:0]`. Lower 5 bits of operand `b` specify the shift amount.
- **`ALU_SLT`**: Set less than signed comparison where `result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0`.
- **`ALU_SLTU`**: Set less than unsigned comparison where `result = (a < b) ? 32'd1 : 32'd0`.
- **`ALU_XOR`**: Bitwise exclusive OR where `result = a ^ b`.
- **`ALU_SRL`**: Shift right logical where `result = a >> b[4:0]` with zero-fill.
- **`ALU_SRA`**: Shift right arithmetic where `result = $signed(a) >>> b[4:0]` preserving the sign bit.
- **`ALU_OR`**: Bitwise OR where `result = a | b`.
- **`ALU_AND`**: Bitwise AND where `result = a & b`.

## 5. Flag Generation
- **Zero Flag (`zero`)**: Evaluated combinational logic: `assign zero = (result == {XLEN{1'b0}});`. This flag directly informs the core decision logic whether equality branch conditions are satisfied.
