class generator;
  mailbox #(riscv_trans) out_mb;
  function new(mailbox #(riscv_trans) out_mb); this.out_mb = out_mb; endfunction
  task run(int count = 10);
    riscv_trans tr;
    repeat (count) begin
      tr = new();
      if (!tr.randomize()) $fatal(1, "Transaction randomization failed");
      out_mb.put(tr);
    end
  endtask
endclass

