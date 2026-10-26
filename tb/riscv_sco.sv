class riscv_sco;
  mailbox #(riscv_trans) in_mb;
  int checked;
  function new(mailbox #(riscv_trans) in_mb); this.in_mb = in_mb; endfunction
  task run();
    riscv_trans tr;
    forever begin
      in_mb.get(tr);
      checked++;
      // Extend this reference model with architectural register/memory state.
    end
  endtask
endclass

