`ifndef TB_TOP_SV
`define TB_TOP_SV

`include "riscv_if.sv"
`include "environment.sv"

// Top-level testbench instantiating the RV32I core and verification environment
module tb_top;
    // 100 MHz system clock (10 ns period)
    bit clk;
    always #5 clk = ~clk;

    // Interface connecting testbench components to the processor
    riscv_if vif(clk);

    // Device Under Test (single-cycle RV32I processor core)
    riscv_core dut (
        .clk   (vif.clk),
        .reset (vif.reset)
    );

    // Hierarchical probes routing internal processor signals to the monitor
    assign vif.pc_current     = dut.pc_current;
    assign vif.pc_next        = dut.pc_next;
    assign vif.instruction    = dut.instruction;
    assign vif.alu_result     = dut.alu_result;
    assign vif.reg_write_en   = dut.RegWrite;
    assign vif.reg_write_addr = dut.rd;
    assign vif.reg_write_data = dut.result_mux_out;
    assign vif.mem_write_en   = dut.MemWrite;
    assign vif.mem_addr       = dut.alu_result;
    assign vif.mem_write_data = dut.rd2;

    // Backdoor loader writing instructions directly into instruction memory during reset
    always @(posedge clk) begin
        if (vif.imem_write_en === 1'b1 && (vif.imem_addr >> 2) < 256)
            dut.imem_module.memory[vif.imem_addr >> 2] = vif.imem_wdata;
    end

    environment env;

    // Build the verification environment with 50 random instructions and run the test
    initial begin
        env = new(vif, 50);
        env.main();
        $display("[TB] Simulation finished at %0t", $time);
        $finish;
    end
endmodule

`endif
