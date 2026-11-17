# Verification results

## Overview

This repository contains a layered, class-based SystemVerilog verification environment (without UVM) for a 32-bit single-cycle RV32I core. The target tool is Vivado 2019.1 XSim. The environment covers 37 instructions: 10 R-type, 9 I-type ALU, 5 loads, 3 stores, 6 branches, JAL, JALR, LUI, and AUIPC. FENCE, ECALL, and EBREAK are excluded.

## Environment components

The testbench components are:

- [`tb/riscv_if.sv`](../tb/riscv_if.sv) - interface
- [`tb/riscv_trans.sv`](../tb/riscv_trans.sv) - randomized transaction
- [`tb/generator.sv`](../tb/generator.sv) - stimulus generation
- [`tb/driver.sv`](../tb/driver.sv) - instruction-memory loading and reset control
- [`tb/monitor.sv`](../tb/monitor.sv) - DUT sampling at the negative edge
- [`tb/riscv_sco.sv`](../tb/riscv_sco.sv) - scoreboard and golden model
- [`tb/environment.sv`](../tb/environment.sv) - environment assembly
- [`tb/tb_top.sv`](../tb/tb_top.sv) - simulation top

The RTL sources are under [`rtl/`](../rtl/).

## Test program structure

The generated program contains 185 instructions plus 16 NOP pad words, fitting the 256-word instruction memory:

- Phase 0: initialise x1..x31 using LUI+ADDI.
- Phase 0b: 16 x `SW x0` to zero data memory.
- Phase 1: directed tests for all 37 instructions; each branch is run twice (first with rs1==rs2).
- Phase 2: 50 constrained-random instructions.
- A sacrificial NOP follows every control-flow instruction.

## Multi-seed results

| Seed | Checked | Passed | Failed | Branches taken/not taken |
|------|---------|--------|--------|--------------------------|
| 1    | 176     | 176    | 0      | 6 / 9                    |
| 2    | 176     | 176    | 0      | 7 / 6                    |
| 3    | 174     | 174    | 0      | 9 / 5                    |

All 37 RV32I instructions were executed in every run. Logs: `logs/seed_runs/`.

Checked < Loaded (185) because taken branches and jumps skip their sacrificial NOP.

## File index

- [How to reproduce](how_to_reproduce.md)
- [Coverage summary](coverage_summary.md)
- [Known limitations](known_limitations.md)
- [Seed logs](logs/seed_runs/README.md)
