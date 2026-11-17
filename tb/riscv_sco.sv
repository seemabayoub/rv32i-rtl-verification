`ifndef RISCV_SCO_SV
`define RISCV_SCO_SV

`include "riscv_trans.sv"

// Golden reference model and checker for all 37 base RV32I instructions
class scoreboard;
    mailbox #(riscv_trans) mon2sco;

    // Test status and transaction counters
    int no_transactions = 0;
    int pass_count      = 0;
    int fail_count      = 0;
    bit done            = 0;
    bit [31:0] prog_end = 32'hFFFF_FFFF; // Byte address where padding NOPs begin

    // Architectural state of the golden reference model
    bit [31:0] ref_reg  [32];
    bit [7:0]  ref_dmem [1024];          // 256 words (1024 bytes), initialized to zero
    bit [31:0] exp_pc;

    // Instruction execution and branch coverage counters
    int        exec_cnt [string];
    int        br_taken_cnt     = 0;
    int        br_not_taken_cnt = 0;
    string     mnem_list [37];

    bit         txn_ok;
    riscv_trans cur;

    function new(mailbox #(riscv_trans) mon2sco);
        string names [37] = '{"ADD","SUB","SLL","SLT","SLTU","XOR","SRL","SRA","OR","AND",
                              "ADDI","SLTI","SLTIU","XORI","ORI","ANDI","SLLI","SRLI","SRAI",
                              "LB","LH","LW","LBU","LHU","SB","SH","SW",
                              "BEQ","BNE","BLT","BGE","BLTU","BGEU",
                              "JAL","JALR","LUI","AUIPC"};
        this.mon2sco = mon2sco;
        foreach (ref_reg[i])  ref_reg[i]   = 32'h0;
        foreach (ref_dmem[i]) ref_dmem[i]  = 8'h00;
        foreach (names[i])    mnem_list[i] = names[i];
        exp_pc = 32'h0;
    endfunction

    // Compares an expected value against the DUT value and logs any mismatch
    function void chk(string what, logic [31:0] expv, logic [31:0] actv);
        if (expv !== actv) begin
            txn_ok = 0;
            $error("[SCB] MISMATCH %-6s | PC=0x%08h INSTR=0x%08h | %s | expected=0x%08h actual=0x%08h",
                   cur_name(), cur.actual_pc, cur.actual_instruction, what, expv, actv);
        end
    endfunction

    string last_mn = "?";
    function string cur_name();
        return last_mn;
    endfunction

    // Reference ALU calculation (alt selects SUB for R-type and SRA/SRAI for right shifts)
    function bit [31:0] alu_calc(bit [2:0] f3, bit alt, bit [31:0] a, bit [31:0] b);
        bit signed [31:0] sa, sb;
        bit [31:0] r;
        sa = a; sb = b;
        case (f3)
            3'b000: begin if (alt) r = a - b; else r = a + b; end
            3'b001: r = a << b[4:0];
            3'b010: begin if (sa < sb) r = 32'd1; else r = 32'd0; end
            3'b011: begin if (a  < b)  r = 32'd1; else r = 32'd0; end
            3'b100: r = a ^ b;
            3'b101: begin
                        if (alt) r = sa >>> b[4:0]; // Arithmetic shift preserves sign bit
                        else     r = a  >>  b[4:0]; // Logical shift fills with zeros
                    end
            3'b110: r = a | b;
            3'b111: r = a & b;
            default: r = 32'h0;
        endcase
        return r;
    endfunction

    // Reads a single byte from the little-endian reference memory (masked to 1024 bytes)
    function bit [7:0] rb(bit [31:0] a);
        return ref_dmem[a & 32'h3FF];
    endfunction

    // Loads byte, halfword, or word from reference memory with sign or zero extension
    function bit [31:0] mem_read(bit [31:0] a, bit [2:0] f3);
        bit [7:0] b0, b1, b2, b3;
        b0 = rb(a); b1 = rb(a + 1); b2 = rb(a + 2); b3 = rb(a + 3);
        case (f3)
            3'b000:  return {{24{b0[7]}}, b0};     // LB
            3'b001:  return {{16{b1[7]}}, b1, b0}; // LH
            3'b010:  return {b3, b2, b1, b0};      // LW
            3'b100:  return {24'h0, b0};           // LBU
            3'b101:  return {16'h0, b1, b0};       // LHU
            default: return 32'h0;
        endcase
    endfunction

    // Updates reference memory on SB, SH, or SW instructions
    function void mem_write(bit [31:0] a, bit [2:0] f3, bit [31:0] d);
        ref_dmem[(a    ) & 32'h3FF] = d[7:0];
        if (f3 == 3'b001 || f3 == 3'b010) ref_dmem[(a + 1) & 32'h3FF] = d[15:8];
        if (f3 == 3'b010) begin
            ref_dmem[(a + 2) & 32'h3FF] = d[23:16];
            ref_dmem[(a + 3) & 32'h3FF] = d[31:24];
        end
    endfunction

    // Decodes one retired instruction, computes expected results, and checks DUT signals
    function void check_one(riscv_trans t);
        logic [31:0] ins, pc;
        bit [6:0]  opc, f7;
        bit [2:0]  f3;
        bit [4:0]  rs1, rs2, rd;
        bit [31:0] v1, v2, imm_i, imm_s, imm_b, imm_u, imm_j;
        bit [31:0] exp_rd, exp_next, ea;
        bit signed [31:0] s1, s2;
        bit        wr_rd, taken, is_store, alt;
        string     mn;

        txn_ok = 1; cur = t; last_mn = "?";
        ins = t.actual_instruction;
        pc  = t.actual_pc;

        // Fail immediately if instruction or PC contains unknown (X/Z) bits
        if ((^ins) === 1'bx || (^pc) === 1'bx) begin
            txn_ok = 0;
            $error("[SCB] X/Z on instruction or PC: PC=0x%08h INSTR=0x%08h", pc, ins);
            exp_pc = pc + 4;
            return;
        end

        // Verify current PC matches the expected next PC from the previous cycle
        chk("PC sequence", exp_pc, pc);

        // Extract instruction fields and read source operands from golden register file
        opc = ins[6:0];   rd  = ins[11:7];  f3 = ins[14:12];
        rs1 = ins[19:15]; rs2 = ins[24:20]; f7 = ins[31:25];
        v1  = ref_reg[rs1]; v2 = ref_reg[rs2];
        s1  = v1; s2 = v2;

        // Reconstruct all five RV32I immediate formats
        imm_i = {{20{ins[31]}}, ins[31:20]};
        imm_s = {{20{ins[31]}}, ins[31:25], ins[11:7]};
        imm_b = {{19{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
        imm_u = {ins[31:12], 12'h0};
        imm_j = {{11{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};

        exp_next = pc + 32'd4;
        wr_rd = 0; exp_rd = 0; is_store = 0; mn = "UNKNOWN";

        case (opc)
            // R-Type register-register ALU operations
            7'b0110011: begin
                wr_rd  = 1;
                exp_rd = alu_calc(f3, f7[5], v1, v2);
                case (f3)
                    3'b000: begin if (f7[5]) mn = "SUB"; else mn = "ADD"; end
                    3'b001: mn = "SLL";
                    3'b010: mn = "SLT";
                    3'b011: mn = "SLTU";
                    3'b100: mn = "XOR";
                    3'b101: begin if (f7[5]) mn = "SRA"; else mn = "SRL"; end
                    3'b110: mn = "OR";
                    3'b111: mn = "AND";
                endcase
            end
            // I-Type immediate ALU operations
            7'b0010011: begin
                wr_rd  = 1;
                alt    = (f3 == 3'b101) ? ins[30] : 1'b0;
                exp_rd = alu_calc(f3, alt, v1, imm_i);
                case (f3)
                    3'b000: mn = "ADDI";
                    3'b010: mn = "SLTI";
                    3'b011: mn = "SLTIU";
                    3'b100: mn = "XORI";
                    3'b110: mn = "ORI";
                    3'b111: mn = "ANDI";
                    3'b001: mn = "SLLI";
                    3'b101: begin if (ins[30]) mn = "SRAI"; else mn = "SRLI"; end
                endcase
            end
            // Data memory loads
            7'b0000011: begin
                wr_rd  = 1;
                ea     = v1 + imm_i;
                exp_rd = mem_read(ea, f3);
                case (f3)
                    3'b000: mn = "LB";
                    3'b001: mn = "LH";
                    3'b010: mn = "LW";
                    3'b100: mn = "LBU";
                    3'b101: mn = "LHU";
                endcase
                last_mn = mn;
                chk("load address (alu_result)", ea, t.actual_alu_result);
            end
            // Data memory stores
            7'b0100011: begin
                is_store = 1;
                ea = v1 + imm_s;
                case (f3)
                    3'b000: mn = "SB";
                    3'b001: mn = "SH";
                    3'b010: mn = "SW";
                endcase
                last_mn = mn;
                chk("mem_write_en",   32'd1, {31'b0, t.actual_mem_write_en});
                chk("mem_addr",       ea,    t.actual_mem_addr);
                chk("mem_write_data", v2,    t.actual_mem_write_data);
                mem_write(ea, f3, v2);
            end
            // Conditional branches
            7'b1100011: begin
                case (f3)
                    3'b000: begin mn = "BEQ";  taken = (v1 == v2); end
                    3'b001: begin mn = "BNE";  taken = (v1 != v2); end
                    3'b100: begin mn = "BLT";  taken = (s1 <  s2); end
                    3'b101: begin mn = "BGE";  taken = (s1 >= s2); end
                    3'b110: begin mn = "BLTU"; taken = (v1 <  v2); end
                    3'b111: begin mn = "BGEU"; taken = (v1 >= v2); end
                    default: begin mn = "BAD_BRANCH"; taken = 0; txn_ok = 0; end
                endcase
                exp_next = taken ? (pc + imm_b) : (pc + 32'd4);
                if (taken) br_taken_cnt++; else br_not_taken_cnt++;
            end
            // Unconditional jumps (JAL and JALR)
            7'b1101111: begin
                mn = "JAL"; wr_rd = 1; exp_rd = pc + 32'd4; exp_next = pc + imm_j;
            end
            7'b1100111: begin
                mn = "JALR"; wr_rd = 1; exp_rd = pc + 32'd4;
                exp_next = (v1 + imm_i) & 32'hFFFF_FFFE;
            end
            // Upper-immediate instructions (LUI and AUIPC)
            7'b0110111: begin mn = "LUI";   wr_rd = 1; exp_rd = imm_u;      end
            7'b0010111: begin mn = "AUIPC"; wr_rd = 1; exp_rd = pc + imm_u; end
            default: begin
                txn_ok = 0;
                $error("[SCB] Unsupported opcode 7'b%07b PC=0x%08h INSTR=0x%08h", opc, pc, ins);
            end
        endcase
        last_mn = mn;

        // Check register file writeback signals (skip when rd == x0 since x0 is hardwired to 0)
        if (wr_rd) begin
            if (rd != 5'd0) begin
                chk("reg_write_en",   32'd1,       {31'b0, t.actual_reg_write_en});
                chk("reg_write_addr", {27'b0, rd}, {27'b0, t.actual_reg_write_addr});
                chk("reg_write_data", exp_rd,      t.actual_reg_write_data);
            end
        end else begin
            chk("reg_write_en (must be 0)", 32'd0, {31'b0, t.actual_reg_write_en});
        end

        // Ensure data memory write enable stays deasserted on non-store instructions
        if (!is_store) chk("mem_write_en (must be 0)", 32'd0, {31'b0, t.actual_mem_write_en});

        // Verify next PC calculation for all instructions
        chk("pc_next", exp_next, t.actual_pc_next);

        // Commit golden state updates for the next cycle
        if (wr_rd && rd != 5'd0) ref_reg[rd] = exp_rd;
        ref_reg[0] = 32'h0;
        exp_pc = exp_next;

        if (!exec_cnt.exists(mn)) exec_cnt[mn] = 0;
        exec_cnt[mn] = exec_cnt[mn] + 1;
    endfunction

    // Consumes monitored cycles until execution enters the trailing NOP padding
    task main();
        riscv_trans t;
        forever begin
            mon2sco.get(t);
            if (done) continue;
            if (t.actual_pc >= prog_end) begin
                done = 1;
                continue;
            end
            no_transactions++;
            check_one(t);
            if (txn_ok) pass_count++;
            else        fail_count++;
        end
    endtask

    // Prints per-instruction execution counts and overall test verdict
    function void report();
        int missing = 0;
        $display("====================== SCOREBOARD REPORT ======================");
        foreach (mnem_list[i]) begin
            if (exec_cnt.exists(mnem_list[i]))
                $display("  %-6s executed %0d time(s)", mnem_list[i], exec_cnt[mnem_list[i]]);
            else begin
                $display("  %-6s *** NEVER EXECUTED ***", mnem_list[i]);
                missing++;
            end
        end
        $display("  Branches taken: %0d | not taken: %0d", br_taken_cnt, br_not_taken_cnt);
        $display("  Instructions checked: %0d | PASS: %0d | FAIL: %0d",
                 no_transactions, pass_count, fail_count);
        if (fail_count == 0 && missing == 0 && done)
            $display("  >>> TEST PASSED : all 37 RV32I instructions executed and matched <<<");
        else
            $display("  >>> TEST FAILED (fail=%0d, uncovered=%0d, program_finished=%0b) <<<",
                     fail_count, missing, done);
        $display("===============================================================");
    endfunction
endclass

`endif
