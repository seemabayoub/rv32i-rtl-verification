# 32-Bit Single-Cycle RV32I Processor with a Class-Based SystemVerilog Testbench

A 32-bit single-cycle RV32I processor core and a self-checking, class-based SystemVerilog verification environment. The testbench uses standard SystemVerilog OOP (classes, mailboxes, virtual interfaces). It does not use UVM.

## Overview

| Item | Value |
|---|---|
| Datapath width | 32 bits (`XLEN = 32`) |
| Execution model | Single cycle, one instruction per clock |
| Registers | `x0`-`x31`, `x0` hardwired to zero |
| Instruction memory | 256 x 32-bit words (`imem`) |
| Data memory | 256 x 32-bit words, byte-addressable (`dmem`) |
| Memory access widths | Byte, halfword, word (signed and unsigned loads) |
| Instructions | 37 base RV32I instructions |
| Simulator | Xilinx Vivado 2019.1 XSim |

`FENCE`, `ECALL`, and `EBREAK` are not implemented.

In every recorded run (seeds 1, 2, 3), all 37 instructions were executed at least once and matched the scoreboard's golden model. The scoreboard reports execution counts per instruction. It does not implement a functional-coverage model or collect code coverage.

## Repository Structure

```text
.
├── RTL
│   ├── riscv_pkg.sv        Shared enums: opcode_e, alu_op_e
│   ├── programcounter.sv   PC register (async reset, stall input)
│   ├── imem.sv             256-word instruction memory, async read
│   ├── regfile.sv          32x32 register file, x0 hardwired to zero
│   ├── immgen.sv           I/S/B/U/J immediate generation
│   ├── control_unit.sv     Main decoder and ALU decoder
│   ├── alu.sv              ALU with zero flag
│   ├── dmem.sv             Byte-addressable data memory
│   └── riscv_core.sv       Top-level core
│
├── Verification
│   ├── riscv_if.sv         Interface: reset, imem load signals, observed DUT signals
│   ├── riscv_trans.sv      Transaction: rand fields, constraints, instruction packing
│   ├── generator.sv        Multi-phase directed + random instruction generator
│   ├── driver.sv           Loads program into imem while reset is high
│   ├── monitor.sv          Samples DUT signals at negedge clk
│   ├── riscv_sco.sv        Scoreboard with golden reference model
│   ├── environment.sv      Creates and connects all components
│   └── tb_top.sv           Clock, DUT, probes, imem backdoor, test entry point
│
└── verification_results/   Logs and documentation of the verification runs
```

If this repository is a Vivado project, the RTL files are under `*.srcs/sources_1/new/` and the testbench files under `*.srcs/sim_1/new/`.

## Processor Architecture

### Datapath

```text
                    pc_next
        +----------------------------------------------+
        |                                              |
        v                                              |
 +--------------+  pc_current   +--------+             |
 | programcounter|------------->|  imem  |             |
 +--------------+       |       +---+----+             |
                        |           | instruction      |
                        |   +-------+----------+       |
                        |   |       |          |       |
                        |   v       v          v       |
                        | +-------+ +--------+ +--------------+
                        | |regfile| | immgen | | control_unit |
                        | +-+---+-+ +---+----+ +------+-------+
                        |   |   |       | imm_ext     | RegWrite, MemWrite, ALUSrcA,
                        |  rd1 rd2      |             | ALUSrcB, ResultSrc, Branch,
                        |   |   |       |             | Jump, ALUControl
                        |   v   v       v             |
                        | ALUSrcA mux  ALUSrcB mux    |
                        | (rd1 / PC)   (rd2 / imm)    |
                        |       \         /           |
                        |        v       v            |
                        |       +---------+           |
                        |       |   ALU   |<----------+
                        |       +----+----+
                        |            | alu_result, alu_zero
                        |            v
                        |       +---------+  address = alu_result
                        |       |  dmem   |  write_data = rd2
                        |       +----+----+
                        |            | dmem_read_data
                        |            v
                        |     ResultSrc mux --> result_mux_out --> regfile write_data
                        |     (ALU / dmem / PC+4 / imm)
                        |
                        +--> next-PC logic (take_branch, Jump, imm_ext, alu_result) --> pc_next
```

### Module Details

**`programcounter`**
- Asynchronous active-high `reset`, which sets `pc_current` to `32'h0`.
- Has a `stall` input. `riscv_core` ties it to `1'b0`.

**`imem`**
- Word index is `address[$clog2(DEPTH)+1:2]`.
- Asynchronous read.
- `initial` block calls `$readmemh("program.mem", memory)`. In the testbench this file does not exist, so XSim prints a harmless warning. The program is loaded through the backdoor in `tb_top.sv`.

**`regfile`**
- 32 registers of `XLEN` bits.
- Synchronous reset on `posedge clk` clears all registers.
- Writes occur on `posedge clk` when `RegWrite` is high and `write_addr != 0`.
- Asynchronous reads. Reading address 0 returns zero.

**`immgen`**
- I-type (`OP_LOAD`, `OP_I_TYPE`, `OP_JALR`): `{{20{instr[31]}}, instr[31:20]}`
- S-type (`OP_STORE`): `{{20{instr[31]}}, instr[31:25], instr[11:7]}`
- B-type (`OP_BRANCH`): `{{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}`
- U-type (`OP_LUI`, `OP_AUIPC`): `{instr[31:12], 12'b0}`
- J-type (`OP_JAL`): `{{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}`
- Unknown opcodes produce zero.

**`control_unit`**
- Main decoder drives `RegWrite`, `MemWrite`, `ALUSrcA`, `ALUSrcB`, `ResultSrc[1:0]`, `Branch`, `Jump[1:0]`.
- ALU decoder produces `ALUControl[3:0]` from opcode, `funct3`, and `funct7_5` (instruction bit 30).
- Branch ALU operations: BEQ/BNE use `ALU_SUB`, BLT/BGE use `ALU_SLT`, BLTU/BGEU use `ALU_SLTU`.
- Loads, stores, AUIPC, JAL, and JALR use `ALU_ADD`.

**`alu`**
- Operations: `ALU_ADD`, `ALU_SUB`, `ALU_SLL`, `ALU_SLT`, `ALU_SLTU`, `ALU_XOR`, `ALU_SRL`, `ALU_SRA`, `ALU_OR`, `ALU_AND`.
- Shift amount is `b[4:0]`.
- `ALU_SRA` uses `$signed(a) >>> b[4:0]`.
- `zero` is high when `result == 0`.

**`dmem`**
- `word_addr = address[$clog2(DEPTH)+1:2]`, `byte_offset = address[1:0]`.
- All words are zeroed in an `initial` block.
- Synchronous write on `posedge clk`: `SB` (funct3 `000`) writes one byte selected by `byte_offset`, `SH` (`001`) writes the half selected by `byte_offset[1]`, `SW` (`010`) writes a word.
- Asynchronous read: `LB` (`000`) and `LH` (`001`) sign-extend, `LW` (`010`) returns the word, `LBU` (`100`) and `LHU` (`101`) zero-extend.

**`riscv_core`**
- Instruction fields are decoded with continuous assignments: `opcode_wire = instruction[6:0]`, `funct3 = instruction[14:12]`, `funct7_5 = instruction[30]`, `rs1 = instruction[19:15]`, `rs2 = instruction[24:20]`, `rd = instruction[11:7]`.
- `alu_src_a = ALUSrcA ? pc_current : rd1`, `alu_src_b = ALUSrcB ? imm_ext : rd2`.
- Writeback mux (`ResultSrc`): `00` ALU result, `01` `dmem_read_data`, `10` `pc_current + 4`, `11` `imm_ext`.
- Branch condition (`take_branch`, only when `Branch` is high):
  - `000` BEQ: `alu_zero`
  - `001` BNE: `!alu_zero`
  - `100` BLT and `110` BLTU: `alu_result[0]`
  - `101` BGE and `111` BGEU: `!alu_result[0]`
- Next PC:
  - `Jump == 2'b10` (JALR): `alu_result & 32'hFFFFFFFE`
  - `Jump == 2'b01` (JAL) or `take_branch`: `pc_current + imm_ext`
  - Otherwise: `pc_current + 4`

### Main Decoder Control Signals

| Instruction group | Opcode | `RegWrite` | `MemWrite` | `ALUSrcA` | `ALUSrcB` | `ResultSrc` | `Branch` | `Jump` |
|---|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| R-type | `0110011` | 1 | 0 | 0 | 0 | `00` | 0 | `00` |
| I-type ALU | `0010011` | 1 | 0 | 0 | 1 | `00` | 0 | `00` |
| Loads | `0000011` | 1 | 0 | 0 | 1 | `01` | 0 | `00` |
| Stores | `0100011` | 0 | 1 | 0 | 1 | `00` | 0 | `00` |
| Branches | `1100011` | 0 | 0 | 0 | 0 | `00` | 1 | `00` |
| JAL | `1101111` | 1 | 0 | 0 | 0 | `10` | 0 | `01` |
| JALR | `1100111` | 1 | 0 | 0 | 1 | `10` | 0 | `10` |
| LUI | `0110111` | 1 | 0 | 0 | 0 | `11` | 0 | `00` |
| AUIPC | `0010111` | 1 | 0 | 1 | 1 | `00` | 0 | `00` |

Unsupported opcodes keep the default values (all signals zero).

## Supported Instructions (37)

`funct7` is listed only where it is used for decoding. For SLLI/SRLI/SRAI the value is carried in `imm[11:5]`. `-` means the field is not used.

| Type | Instruction | Opcode | `funct3` | `funct7` |
|---|---|---|---|---|
| R | ADD | `0110011` | `000` | `0000000` |
| R | SUB | `0110011` | `000` | `0100000` |
| R | SLL | `0110011` | `001` | `0000000` |
| R | SLT | `0110011` | `010` | `0000000` |
| R | SLTU | `0110011` | `011` | `0000000` |
| R | XOR | `0110011` | `100` | `0000000` |
| R | SRL | `0110011` | `101` | `0000000` |
| R | SRA | `0110011` | `101` | `0100000` |
| R | OR | `0110011` | `110` | `0000000` |
| R | AND | `0110011` | `111` | `0000000` |
| I-ALU | ADDI | `0010011` | `000` | - |
| I-ALU | SLTI | `0010011` | `010` | - |
| I-ALU | SLTIU | `0010011` | `011` | - |
| I-ALU | XORI | `0010011` | `100` | - |
| I-ALU | ORI | `0010011` | `110` | - |
| I-ALU | ANDI | `0010011` | `111` | - |
| I-ALU | SLLI | `0010011` | `001` | `0000000` |
| I-ALU | SRLI | `0010011` | `101` | `0000000` |
| I-ALU | SRAI | `0010011` | `101` | `0100000` |
| Load | LB | `0000011` | `000` | - |
| Load | LH | `0000011` | `001` | - |
| Load | LW | `0000011` | `010` | - |
| Load | LBU | `0000011` | `100` | - |
| Load | LHU | `0000011` | `101` | - |
| Store | SB | `0100011` | `000` | - |
| Store | SH | `0100011` | `001` | - |
| Store | SW | `0100011` | `010` | - |
| Branch | BEQ | `1100011` | `000` | - |
| Branch | BNE | `1100011` | `001` | - |
| Branch | BLT | `1100011` | `100` | - |
| Branch | BGE | `1100011` | `101` | - |
| Branch | BLTU | `1100011` | `110` | - |
| Branch | BGEU | `1100011` | `111` | - |
| Jump | JAL | `1101111` | - | - |
| Jump | JALR | `1100111` | `000` | - |
| U | LUI | `0110111` | - | - |
| U | AUIPC | `0010111` | - | - |

## Verification Environment

### Architecture

```text
 +-----------+   mbx_gen_drv    +----------+
 | generator |----------------->|  driver  |
 +-----------+                  +----+-----+
                                     | reset, imem_write_en,
                                     | imem_addr, imem_wdata
                                     v
                               +-----------+      backdoor write      +------------------+
                               | riscv_if  |------------------------->| riscv_core (DUT) |
                               | (vif)     |  (always block in        |  imem_module     |
                               |           |   tb_top.sv)             +--------+---------+
                               |           |<-------------------------------- |
                               +-----+-----+   hierarchical probes in tb_top   
                                     | pc_current, pc_next, instruction,
                                     | alu_result, reg_write_*, mem_*
                                     v
                                +---------+   mbx_mon_sco   +------------+
                                | monitor |---------------->| scoreboard |
                                +---------+                 | (golden    |
                                                            |  model)    |
                                                            +------------+
```

`environment` creates the generator, driver, monitor, scoreboard and the two mailboxes (`mbx_gen_drv`, `mbx_mon_sco`). `tb_top` provides the 10 ns clock, instantiates `riscv_core`, assigns hierarchical probes to `riscv_if`, and implements the instruction-memory backdoor.

### Transaction and Constraints (`riscv_trans.sv`)

Randomized fields: `opcode`, `rs1`, `rs2`, `rd`, `funct3`, `funct7`, and `imm`. `imm` is `rand bit signed [31:0]` so that negative ranges such as `[-2048:2047]` are valid.

Constraints:
- `opcode` is limited to the 9 RV32I opcode groups.
- `funct7` is zero unless the format uses it. R-type allows `0100000` only for `funct3` `000` (SUB) and `101` (SRA). I-type shifts take `funct7` from `imm[11:5]`.
- Loads and stores use `rs1 = x0`. Immediate is `16` when `directed` is set, otherwise in `[0:63]`. `LW`/`SW` are word-aligned, `LH`/`LHU`/`SH` are halfword-aligned.
- Branches and JAL use forward offsets only: `8` (directed) or `{8, 12}` (random).
- JALR uses `rs1 = x0`, `funct3 = 000`, and an absolute forward target (`pc_addr + 8` or `pc_addr + 12`, set by `set_pc()`).
- LUI and AUIPC have `imm[11:0] == 0`.

`post_randomize()` calls `build()`, which packs the fields into `instruction` using the R/I/S/B/U/J layouts. `make_nop()` builds `ADDI x0, x0, 0` (`32'h0000_0013`).

### Stimulus Phases (`generator.sv`)

| Phase | Content |
|---|---|
| 0 | For `x1`..`x31`: one `LUI` and one `ADDI` (`rd == rs1`) with random values. |
| 0b | 16 x `SW x0, imm(x0)` with `imm = 0, 4, ..., 60`, which zeroes data memory bytes 0-63. |
| 1 | Directed: every one of the 37 instructions, in table order (stores before loads). Each branch is generated twice, first with `rs1 == rs2`, then with random registers. A sacrificial NOP follows every branch, JAL and JALR so a taken forward jump never skips a directed test. |
| 2 | Constrained-random instructions (default 50). |

With the default 50 random instructions the program is 185 words. The driver appends 16 NOP words, so the 256-word `imem` limit allows at most about 105 random instructions. `environment` calls `$fatal` if the program plus padding exceeds 256 words.

### Driver and Reset Sequencing (`driver.sv`, `tb_top.sv`)

1. Drive `reset = 1`, `imem_write_en = 0`.
2. Wait 2 rising clock edges.
3. For each program word, drive `imem_write_en`, `imem_addr = i*4`, and `imem_wdata`, then wait one clock. After the program, write 16 NOP words (`32'h0000_0013`).
4. Deassert `imem_write_en`, wait 3 clock edges, then release `reset`.

The actual memory write is done in `tb_top.sv`:

```systemverilog
always @(posedge clk) begin
    if (vif.imem_write_en === 1'b1 && (vif.imem_addr >> 2) < 256)
        dut.imem_module.memory[vif.imem_addr >> 2] = vif.imem_wdata;
end
```

This is a simulation-only backdoor.

### Monitor (`monitor.sv`)

The monitor samples at `@(negedge vif.clk)`, when `reset === 0` and `imem_write_en === 0`. At negedge the combinational outputs for the current instruction have settled, before the next posedge updates state. It captures `pc_current`, `pc_next`, `instruction`, `alu_result`, `reg_write_en/addr/data`, `mem_write_en`, `mem_addr`, `mem_write_data`, and sends one transaction per cycle to the scoreboard.

### Scoreboard and Golden Model (`riscv_sco.sv`)

State: `ref_reg[32]`, little-endian byte-addressable `ref_dmem[1024]` (zero-initialised), and `exp_pc`.

For each monitored cycle the scoreboard:
- fails on X/Z in the instruction or PC,
- checks that `pc_current` equals the expected PC,
- decodes the instruction and computes the expected result from the shadow register file,
- checks load address (`alu_result`), store `mem_write_en`/`mem_addr`/`mem_write_data`,
- checks `reg_write_en`, `reg_write_addr`, `reg_write_data` (when `rd != x0`), and that `reg_write_en` is 0 for instructions that do not write,
- checks that `mem_write_en` is 0 for non-stores,
- checks `pc_next` (branch taken/not taken, JAL, JALR target),
- updates the shadow state and counts executions per mnemonic and branches taken / not taken.

Mismatches are reported as `[SCB] MISMATCH ...`. The scoreboard stops when `pc_current` reaches the NOP padding (`prog_end = total_trans * 4`). `TEST PASSED` is printed only if there are no failures, all 37 instructions were executed, and the program finished. Otherwise it prints `TEST FAILED`.

## Running the Simulation (Vivado 2019.1 XSim)

### GUI

1. Add the RTL files as design sources.
2. Add the testbench files as simulation sources. `tb_top.sv` includes the other testbench files with `` `include ``.
3. Set the simulation top module to `tb_top`.
4. Run **Simulation > Run Behavioral Simulation**, then `run all` in the Tcl console. The simulation ends with `$finish` from `tb_top`.

### Fixed seed

Set `xsim.simulate.xsim.more_options` to `-sv_seed N` (Simulation Settings, or Tcl):

```tcl
set_property -name {xsim.simulate.xsim.more_options} -value "-sv_seed 1" -objects [get_filesets sim_1]
```

### Command line (not tested for this README)

```bash
xvlog -sv riscv_pkg.sv programcounter.sv imem.sv regfile.sv immgen.sv \
          control_unit.sv alu.sv dmem.sv riscv_core.sv
xvlog -sv tb_top.sv          # pulls in the testbench files via `include
xelab tb_top -s tb_top_sim
xsim tb_top_sim -runall -sv_seed 1
```

### Multiple seeds (Vivado Tcl console)

```tcl
set proj_dir [get_property DIRECTORY [current_project]]
set proj_name [current_project]
set simlog "$proj_dir/$proj_name.sim/sim_1/behav/xsim/simulate.log"
set outdir "$proj_dir/seed_logs"
file mkdir $outdir
foreach s {1 2 3} {
    catch {close_sim -force}
    set_property -name {xsim.simulate.xsim.more_options} -value "-sv_seed $s" -objects [get_filesets sim_1]
    launch_simulation
    run all
    catch {close_sim -force}
    file copy -force $simlog "$outdir/seed_$s.log"
    puts "=== seed $s done, saved to $outdir/seed_$s.log ==="
}
```

`simulate.log` is overwritten on every run, so copy it right after each run.

### Harmless messages

- `program.mem ... cannot be opened for reading` (from `imem.sv`; the program is loaded by the backdoor).
- Webtalk error when the project path contains spaces.
- `env was not traceable` waveform warning.
- `glbl` timescale warning.

## Sample Simulation Output (seed 1)

```text
[Environment] Loaded: 185 instr | Checked: 176 | Passed: 176 | Failed: 0
====================== SCOREBOARD REPORT ======================
     ADD executed 6 time(s)
     SUB executed 7 time(s)
     SLL executed 4 time(s)
     SLT executed 1 time(s)
    SLTU executed 4 time(s)
     XOR executed 3 time(s)
     SRL executed 11 time(s)
     SRA executed 7 time(s)
      OR executed 5 time(s)
     AND executed 3 time(s)
    ADDI executed 39 time(s)
    SLTI executed 1 time(s)
   SLTIU executed 1 time(s)
    XORI executed 1 time(s)
     ORI executed 1 time(s)
    ANDI executed 1 time(s)
    SLLI executed 1 time(s)
    SRLI executed 1 time(s)
    SRAI executed 1 time(s)
      LB executed 1 time(s)
      LH executed 1 time(s)
      LW executed 1 time(s)
     LBU executed 1 time(s)
     LHU executed 2 time(s)
      SB executed 2 time(s)
      SH executed 1 time(s)
      SW executed 17 time(s)
     BEQ executed 2 time(s)
     BNE executed 2 time(s)
     BLT executed 2 time(s)
     BGE executed 3 time(s)
    BLTU executed 3 time(s)
    BGEU executed 3 time(s)
     JAL executed 2 time(s)
    JALR executed 1 time(s)
     LUI executed 32 time(s)
   AUIPC executed 2 time(s)
  Branches taken: 6 | not taken: 9
  Instructions checked: 176 | PASS: 176 | FAIL: 0
  >>> TEST PASSED : all 37 RV32I instructions executed and matched <<<
===============================================================
[TB] Simulation finished at 3845000
```

The full log is in `verification_results/logs/seed_runs/seed_1.log`.

## Multi-Seed Results

| Seed | Checked | Passed | Failed | Branches taken / not taken |
|------|---------|--------|--------|----------------------------|
| 1 | 176 | 176 | 0 | 6 / 9 |
| 2 | 176 | 176 | 0 | 7 / 6 |
| 3 | 174 | 174 | 0 | 9 / 5 |

All 37 instructions were executed in every run. Checked is lower than Loaded (185) because taken branches and jumps skip their sacrificial NOP.

Logs and details: [`verification_results/`](verification_results/).

## Known Limitations

- Load/store base register is always `x0` (address = immediate, 0-63 in random mode).
- Branch and JAL offsets are forward only (`8` or `12` bytes). Backward branches and loops are not generated.
- JALR uses `rs1 = x0` with an absolute forward target.
- Misaligned halfword/word accesses are not generated, and `dmem` does not handle accesses that cross a word boundary.
- The scoreboard does not check `reg_write_en` when `rd == x0`.
- The golden register file is not resynchronised after a mismatch, so one bug can cascade. Read the first `[SCB] MISMATCH` line.
- Data memory is zero-initialised in both the RTL and the scoreboard, so reads of never-written memory are not tested.
- The program plus 16 padding words must fit in the 256-word instruction memory.
- No functional-coverage model or code-coverage report is included. "Coverage" here means every instruction was executed and checked.
