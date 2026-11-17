# Known limitations

- Load/store base register is always x0 (address = immediate, 0..63).
- Branch/JAL offsets are forward only ({8,12} bytes); no backward jumps or loops.
- JALR uses rs1=x0 with an absolute forward target.
- `reg_write_en` is not checked when rd==x0.
- The golden register file is not resynced after a mismatch, so one bug cascades. Always read the FIRST `[SCB] MISMATCH` line.
- Data memory is zero-initialised in RTL and in the scoreboard, so reads of never-written memory are not tested.
- The program must fit in the 256-word instruction memory (max about 105 random instructions with the current directed part).
