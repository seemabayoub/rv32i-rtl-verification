# Register File Specification

The register file contains thirty-two 32-bit registers named `x0` through `x31`.

- `x0` is hardwired to zero: reads always return `32'b0`.
- Writes to `x0` are ignored.
- Other writes occur on the rising edge when `write_enable` is asserted.
- Two combinational read ports support the standard RV32I `rs1` and `rs2` operands.
- Reset clears all registers in the template for deterministic simulation.

