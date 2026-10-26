# ALU Specification

## Purpose

The ALU accepts two 32-bit operands and performs the operation selected by `alu_op`. It is combinational and has no internal state.

## Operations

| Operation | Description |
|---|---|
| `ADD` | `a + b` |
| `SUB` | `a - b` |
| `AND`, `OR`, `XOR` | Bitwise logical operation |
| `SLL`, `SRL`, `SRA` | Logical/arithmetic shifts using `b[4:0]` |
| `SLT`, `SLTU` | Signed/unsigned less-than; result is 0 or 1 |

The `zero` output is asserted when the 32-bit result is zero and is used by conditional branches. Arithmetic wraps modulo 2^32.

## Control

`alu_op` is the `alu_op_t` enum in `rtl/riscv_pkg.sv`. R-type instructions select the operation from `funct3` and `funct7`; address generation uses `ADD`; branch comparison uses `SUB` or a dedicated comparison operation.

