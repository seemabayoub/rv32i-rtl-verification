class driver;
  virtual riscv_if vif;
  mailbox #(riscv_trans) in_mb;
  function new(virtual riscv_if vif, mailbox #(riscv_trans) in_mb);
    this.vif = vif; this.in_mb = in_mb;
  endfunction
  task run();
    riscv_trans tr;
    forever begin
      in_mb.get(tr);
      @(vif.cb);
      vif.cb.instruction <= tr.instruction;
    end
  endtask
endclass

