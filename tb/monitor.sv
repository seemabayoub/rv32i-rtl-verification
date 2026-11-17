`ifndef MONITOR_SV
`define MONITOR_SV

`include "riscv_trans.sv"

// Observes DUT signals each cycle and forwards captured transactions to the scoreboard
class monitor;
    virtual riscv_if vif;
    mailbox #(riscv_trans) mon2sco;
    bit verbose = 0;

    function new(virtual riscv_if vif, mailbox #(riscv_trans) mon2sco);
        this.vif     = vif;
        this.mon2sco = mon2sco;
    endfunction

    // Sample at negedge so combinational signals are settled before the posedge state update
    task main();
        riscv_trans t;
        forever begin
            @(negedge vif.clk);
            if (vif.reset === 1'b0 && vif.imem_write_en === 1'b0) begin
                t = new();

                // Capture current cycle datapath and writeback signals
                t.actual_pc             = vif.pc_current;
                t.actual_pc_next        = vif.pc_next;
                t.actual_instruction    = vif.instruction;
                t.actual_alu_result     = vif.alu_result;
                t.actual_reg_write_en   = vif.reg_write_en;
                t.actual_reg_write_addr = vif.reg_write_addr;
                t.actual_reg_write_data = vif.reg_write_data;
                t.actual_mem_write_en   = vif.mem_write_en;
                t.actual_mem_addr       = vif.mem_addr;
                t.actual_mem_write_data = vif.mem_write_data;

                // Extract instruction bit fields for scoreboard decoding
                t.instruction = vif.instruction;
                t.opcode      = vif.instruction[6:0];
                t.rd          = vif.instruction[11:7];
                t.funct3      = vif.instruction[14:12];
                t.rs1         = vif.instruction[19:15];
                t.rs2         = vif.instruction[24:20];
                t.funct7      = vif.instruction[31:25];
                t.pc_addr     = vif.pc_current;

                if (verbose) t.display("MONITOR");
                mon2sco.put(t);
            end
        end
    endtask
endclass

`endif
