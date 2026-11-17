
`ifndef DRIVER_SV
`define DRIVER_SV

`include "riscv_trans.sv"

// Pre-loads generated instructions into instruction memory before releasing reset
class driver;
    virtual riscv_if vif;
    mailbox #(riscv_trans) gen2driv;
    int no_transactions = 0;
    int prog_words      = 0;
    int pad_words; // Extra NOPs added after the program to avoid hitting X memory

    function new(virtual riscv_if vif, mailbox #(riscv_trans) gen2driv, int pad_words = 16);
        this.vif       = vif;
        this.gen2driv  = gen2driv;
        this.pad_words = pad_words;
    endfunction

    // Run after generator.main() has pushed all transactions into the mailbox
    task main();
        riscv_trans trans;
        int n;

        n = gen2driv.num();
        prog_words = n;

        // Hold the processor in reset while we initialize instruction memory
        vif.reset         <= 1'b1;
        vif.imem_write_en <= 1'b0;
        vif.imem_addr     <= 32'd0;
        vif.imem_wdata    <= 32'd0;
        repeat (2) @(posedge vif.clk);

        // Write program words to imem, followed by NOPs (ADDI x0, x0, 0) as a safe landing zone
        for (int i = 0; i < n + pad_words; i++) begin
            vif.imem_write_en <= 1'b1;
            vif.imem_addr     <= i * 4;
            if (i < n) begin
                gen2driv.get(trans);
                vif.imem_wdata <= trans.instruction;
                no_transactions++;
            end else begin
                vif.imem_wdata <= 32'h0000_0013; // NOP padding after the program
            end
            @(posedge vif.clk);
        end

        // Stop imem writes, wait a few cycles for signals to settle, then start execution at PC = 0
        vif.imem_write_en <= 1'b0;
        repeat (3) @(posedge vif.clk);
        vif.reset <= 1'b0;
    endtask
endclass

`endif
