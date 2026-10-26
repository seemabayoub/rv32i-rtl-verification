# Core Integration Specification

`riscv_core` connects the program counter, instruction memory, immediate generator, register file, control unit, ALU, and data memory. The default flow is:

1. Fetch the instruction at `pc`.
2. Decode fields and generate the immediate and controls.
3. Execute an ALU operation or calculate a branch/jump target.
4. Read or write data memory.
5. Select the register write-back value.
6. Update `pc` to `pc + 4`, a taken branch target, or a jump target.

The top-level data-memory interface is exposed for integration and verification. Reset is synchronous and active-high. `halt` is reserved for a future trap/termination mechanism and is low in the baseline implementation.

