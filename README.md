# RV32I RTL Verification

A modular RV32I RISC-V processor core and layered SystemVerilog verification environment. The project is organized around a small, synthesizable single-cycle datapath and a transaction-based testbench suitable for Xilinx Vivado XSIM.

## Architecture

The core implements the base RV32I integer instruction set using a 32-bit datapath:

- `programcounter.sv` holds the current instruction address and advances by four bytes.
- `imem.sv` supplies a 32-bit instruction from word-addressed instruction storage.
- `control_unit.sv` decodes the instruction opcode and produces datapath controls.
- `immgen.sv` expands I, S, B, U, and J instruction immediates.
- `regfile.sv` provides thirty-two 32-bit registers; `x0` always reads as zero.
- `alu.sv` performs arithmetic, logical, comparison, and address-generation operations.
- `dmem.sv` implements byte-addressed load/store access with byte and halfword sign extension.
- `riscv_core.sv` connects the datapath and control signals.

The initial template uses a single-cycle execution model. Branch and jump target selection, memory access, and register write-back are all visible in the top-level integration module so they can be independently verified.

## Repository layout

```text
specs/   Hardware behavior and interface specifications
rtl/     Synthesizable SystemVerilog source
tb/      Layered transaction, generator, driver, monitor, and scoreboard environment
```

## Simulation with Vivado XSIM

From the repository root, create a Vivado project or use the Vivado Tcl console:

```tcl
read_verilog -sv [glob rtl/*.sv]
read_verilog -sv [glob tb/*.sv]
set_property top tb_top [current_fileset -simset]
launch_simulation
run all
```

For a non-project batch flow, compile the package and RTL before the testbench:

```bash
xvlog -sv rtl/riscv_pkg.sv rtl/*.sv tb/*.sv
xelab tb_top -s rv32i_sim
xsim rv32i_sim -runall
```

The testbench is intentionally a clean template: add directed sequences in `generator.sv`, connect a concrete program or memory initialization in `tb_top.sv`, and extend `riscv_sco.sv` with the reference-model checks required by the test plan.

## Design assumptions

- 32-bit little-endian data and instruction words.
- Byte-addressed memories with configurable depth.
- Synchronous state updates on the rising edge of `clk`.
- Reset is active-high and synchronous.
- Memory contents are initialized to zero unless a project-specific image is loaded.
- Unsupported or illegal instructions produce no architectural write-back.

See the documents in `specs/` for the detailed module contracts and encoding assumptions.
