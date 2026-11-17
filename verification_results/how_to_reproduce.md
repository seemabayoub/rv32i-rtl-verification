# How to reproduce

## Tool and source setup

Use Vivado 2019.1 with XSim. Add the RTL files under [`rtl/`](../rtl/) as design sources. Add [`tb/tb_top.sv`](../tb/tb_top.sv) as the simulation source; it includes [`tb/riscv_if.sv`](../tb/riscv_if.sv) and [`tb/environment.sv`](../tb/environment.sv), and `tb/environment.sv` includes the other testbench class files under [`tb/`](../tb/). Set the simulation top module to `tb_top`.

Run **Run Simulation -> Run Behavioral Simulation**, then run:

```tcl
run all
```

The expected end of a successful run is `TEST PASSED` and `Failed: 0`.

To set a seed, use **Simulation Settings -> xsim.simulate.xsim.more_options** and enter:

```text
-sv_seed N
```

## Running multiple seeds

Run this Tcl script in the Vivado Tcl console:

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

`simulate.log` is overwritten on every run, so it must be copied immediately after each run.

## Harmless messages

The following messages are harmless in this setup:

- `program.mem` cannot be opened (from `imem.sv`).
- A Webtalk error when the project path contains spaces.
- An `env was not traceable` waveform warning.
- A `glbl` timescale warning.
