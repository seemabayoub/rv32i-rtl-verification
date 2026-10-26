# Instruction Memory Specification

Instruction memory is a read-only, byte-addressed array of 32-bit words. The core supplies the program counter as a byte address; the memory ignores the low two bits and indexes by `address[...:2]`.

Instructions are little-endian and aligned to four-byte boundaries. The default implementation returns zero for addresses outside the configured depth. Program images may be loaded using a testbench initialization task or `$readmemh`.

