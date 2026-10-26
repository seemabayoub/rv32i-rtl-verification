# Data Memory Specification

Data memory is a byte-addressed, little-endian array of configurable depth. The default RTL implementation exposes a 32-bit read value and supports byte, halfword, and word transfers.

- `LW` reads four bytes and sign-extends the 32-bit value.
- `LH` reads two bytes and sign-extends bit 15.
- `LHU` reads two bytes and zero-extends.
- `LB` reads one byte and sign-extends bit 7.
- `LBU` reads one byte and zero-extends.
- `SW`, `SH`, and `SB` write four, two, or one bytes respectively.

Reads are combinational in the template; writes occur on the rising edge when `mem_write` is asserted. Unaligned accesses are outside the base contract and should be rejected or constrained by the verification environment.

