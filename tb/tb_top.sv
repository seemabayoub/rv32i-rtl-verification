`timescale 1ns/1ps
module tb_top;
  logic clk = 1'b0;
  always #5 clk = ~clk;
  riscv_if bus(clk);
  riscv_core dut(
    .clk, .reset(bus.reset), .imem_address(bus.imem_address),
    .instruction(bus.instruction), .dmem_read(bus.dmem_read),
    .dmem_write(bus.dmem_write), .dmem_address(bus.dmem_address),
    .dmem_write_data(bus.dmem_write_data), .dmem_width(bus.dmem_width),
    .dmem_unsigned(bus.dmem_unsigned), .dmem_read_data(bus.dmem_read_data),
    .halt(bus.halt)
  );
  mailbox #(riscv_trans) gen_to_drv = new();
  mailbox #(riscv_trans) mon_to_sco = new();
  generator gen;
  driver drv;
  monitor mon;
  riscv_sco sco;
  initial begin
    bus.reset = 1'b1;
    bus.instruction = 32'b0;
    bus.dmem_read_data = 32'b0;
    repeat (2) @(posedge clk);
    bus.reset = 1'b0;
    gen = new(gen_to_drv); drv = new(bus, gen_to_drv);
    mon = new(bus, mon_to_sco); sco = new(mon_to_sco);
    fork
      gen.run(20);
      drv.run();
      mon.run();
      sco.run();
    join_none
    #1000 $finish;
  end
endmodule
