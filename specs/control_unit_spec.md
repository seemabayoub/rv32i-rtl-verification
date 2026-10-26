# Control Unit Specification

The control unit decodes `opcode`, `funct3`, and `funct7` into the control signals consumed by the core. Illegal encodings are disabled by default.

| Opcode | Instruction class | RegWrite | MemRead | MemWrite | Branch | Jump |
|---|---|---:|---:|---:|---:|---:|
| `0110011` | R-type | 1 | 0 | 0 | 0 | 0 |
| `0010011` | I-type ALU | 1 | 0 | 0 | 0 | 0 |
| `0000011` | Load | 1 | 1 | 0 | 0 | 0 |
| `0100011` | Store | 0 | 0 | 1 | 0 | 0 |
| `1100011` | Conditional branch | 0 | 0 | 0 | 1 | 0 |
| `1101111` | JAL | 1 | 0 | 0 | 0 | 1 |
| `1100111` | JALR | 1 | 0 | 0 | 0 | 1 |
| `0110111` | LUI | 1 | 0 | 0 | 0 | 0 |
| `0010111` | AUIPC | 1 | 0 | 0 | 0 | 0 |

The decoder also selects immediate format, ALU source, write-back source, memory width, and signedness. The branch comparator is selected by `funct3`.

