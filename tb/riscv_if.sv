`ifndef RISCV_IF_SV
`define RISCV_IF_SV

// Interface connecting the testbench components to the RISC-V processor signals
interface riscv_if (input logic clk);
    // Signals driven by the driver to reset the core and preload instruction memory
    logic        reset;
    logic        imem_write_en;
    logic [31:0] imem_addr;
    logic [31:0] imem_wdata;

    // Internal datapath and control signals observed by the monitor
    logic [31:0] pc_current;
    logic [31:0] pc_next;
    logic [31:0] instruction;
    logic [31:0] alu_result;
    logic        reg_write_en;
    logic [4:0]  reg_write_addr;
    logic [31:0] reg_write_data;
    logic        mem_write_en;
    logic [31:0] mem_addr;
    logic [31:0] mem_write_data;
endinterface

`endif
