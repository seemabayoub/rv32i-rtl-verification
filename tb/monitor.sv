class monitor;
  virtual riscv_if vif;
  mailbox #(riscv_trans) out_mb;
  function new(virtual riscv_if vif, mailbox #(riscv_trans) out_mb);
    this.vif = vif; this.out_mb = out_mb;
  endfunction
  task run();
    riscv_trans tr;
    forever begin
      @(vif.cb);
      tr = new();
      tr.instruction = vif.cb.instruction;
      out_mb.put(tr);
    end
  endtask
endclass

