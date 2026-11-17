`ifndef ENVIRONMENT_SV
`define ENVIRONMENT_SV

`include "riscv_if.sv"
`include "riscv_trans.sv"
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "riscv_sco.sv"

// Top-level verification environment connecting generator, driver, monitor, and scoreboard
class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sco;

    mailbox #(riscv_trans) mbx_gen_drv;
    mailbox #(riscv_trans) mbx_mon_sco;
    virtual riscv_if vif;
    int total_trans;
    localparam int PAD = 16; // Trailing NOP words added after the program

    function new(virtual riscv_if vif, int num_random_trans = 50);
        this.vif    = vif;
        mbx_gen_drv = new();
        mbx_mon_sco = new();
        gen = new(mbx_gen_drv, num_random_trans);
        drv = new(vif, mbx_gen_drv, PAD);
        mon = new(vif, mbx_mon_sco);
        sco = new(mbx_mon_sco);
    endfunction

    task main();
        int cyc, timeout;

        // Start monitor and scoreboard threads in the background
        fork
            mon.main();
            sco.main();
        join_none

        // Generate all directed and random instructions into the mailbox
        gen.main();
        total_trans = gen.count;
        if (total_trans + PAD > 256)
            $fatal(1, "[ENV] Program (%0d words + pad) does not fit in 256-word imem", total_trans);
        sco.prog_end = total_trans * 4;

        // Preload instruction memory and release processor reset
        drv.main();

        // Wait until PC reaches the trailing NOP padding or hit a safety timeout
        timeout = total_trans * 3 + 200;
        cyc = 0;
        while (!sco.done && cyc < timeout) begin
            @(posedge vif.clk);
            cyc++;
        end
        if (!sco.done)
            $error("[ENV] TIMEOUT: PC never reached end of program (%0d cycles)", cyc);

        // Allow final cycle checks to complete and print the summary report
        repeat (2) @(posedge vif.clk);
        $display("[Environment] Loaded: %0d instr | Checked: %0d | Passed: %0d | Failed: %0d",
                 total_trans, sco.no_transactions, sco.pass_count, sco.fail_count);
        sco.report();
    endtask
endclass

`endif
