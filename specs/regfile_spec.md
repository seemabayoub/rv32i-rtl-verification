# Register File (`regfile`) Specification

## 1. Overview
The Register File module comprises 32 general-purpose registers of width `XLEN` (32 bits). Register `x0` is permanently hardwired to `32'h00000000` and cannot be overwritten. It provides dual asynchronous read ports and a single synchronous write port.

## 2. Parameters
- `XLEN`: Data width parameter set to 32 bits for RV32I architecture compliance.
- `ADDR_WIDTH`: Address bus width set to 5 bits to address 32 registers ($2^5 = 32$).

## 3. Ports Description
| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `clk` | Input | `1` | System clock signal for synchronous register write operations |
| `reset` | Input | `1` | Active-high reset clearing register bank contents |
| `RegWrite` | Input | `1` | Write enable control signal asserted by the control unit |
| `read_addr1` | Input | `5` | Source register 1 address (`rs1`) |
| `read_addr2` | Input | `5` | Source register 2 address (`rs2`) |
| `write_addr` | Input | `5` | Destination register address (`rd`) |
| `write_data` | Input | `XLEN` | Data to be written into the destination register |
| `read_data1` | Output | `XLEN` | Combinational data output sourced from `read_addr1` |
| `read_data2` | Output | `XLEN` | Combinational data output sourced from `read_addr2` |

## 4. Behavioral Implementation Notes
- **Hardwired Zero**: Reading from address `5'b00000` (`x0`) always returns `32'h00000000` regardless of any write operations directed towards it.
- **Synchronous Write**: Writing to a designated register (`write_addr`) occurs on the rising edge of `clk` when `RegWrite` is high and `write_addr != 5'b00000`.
- **Asynchronous Read**: Reads are combinational, allowing data to propagate immediately based on `read_addr1` and `read_addr2`.
