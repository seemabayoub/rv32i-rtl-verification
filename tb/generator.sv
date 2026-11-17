`ifndef GENERATOR_SV
`define GENERATOR_SV

`include "riscv_trans.sv"

// Generates a multi-phase instruction stream (register init, directed RV32I coverage, and random)
class generator;
    mailbox #(riscv_trans) gen2driv;
    event ended;
    int   random_count;
    int   count;          // Total instructions pushed into the mailbox
    bit   init_regs;

    // Lookup tables holding the 37 directed RV32I instruction templates
    bit [6:0] d_op   [37];
    bit [2:0] d_f3   [37];
    bit [6:0] d_f7   [37];
    string    d_name [37];
    int       n_dir;

    function new(mailbox #(riscv_trans) gen2driv, int random_count = 50, bit init_regs = 1);
        this.gen2driv     = gen2driv;
        this.random_count = random_count;
        this.init_regs    = init_regs;
        count = 0;
        n_dir = 0;
        init_directed_test();
    endfunction

    // Helper to append one instruction definition to the directed table
    function void add(bit [6:0] op, bit [2:0] f3, bit [6:0] f7, string name);
        d_op[n_dir] = op; d_f3[n_dir] = f3; d_f7[n_dir] = f7; d_name[n_dir] = name;
        n_dir++;
    endfunction

    // Populates all 37 base RV32I instructions in execution order
    function void init_directed_test();
        // R-Type ALU instructions (10)
        add(7'b0110011, 3'b000, 7'b0000000, "ADD");
        add(7'b0110011, 3'b000, 7'b0100000, "SUB");
        add(7'b0110011, 3'b001, 7'b0000000, "SLL");
        add(7'b0110011, 3'b010, 7'b0000000, "SLT");
        add(7'b0110011, 3'b011, 7'b0000000, "SLTU");
        add(7'b0110011, 3'b100, 7'b0000000, "XOR");
        add(7'b0110011, 3'b101, 7'b0000000, "SRL");
        add(7'b0110011, 3'b101, 7'b0100000, "SRA");
        add(7'b0110011, 3'b110, 7'b0000000, "OR");
        add(7'b0110011, 3'b111, 7'b0000000, "AND");
        // I-Type ALU instructions (9)
        add(7'b0010011, 3'b000, 7'b0000000, "ADDI");
        add(7'b0010011, 3'b010, 7'b0000000, "SLTI");
        add(7'b0010011, 3'b011, 7'b0000000, "SLTIU");
        add(7'b0010011, 3'b100, 7'b0000000, "XORI");
        add(7'b0010011, 3'b110, 7'b0000000, "ORI");
        add(7'b0010011, 3'b111, 7'b0000000, "ANDI");
        add(7'b0010011, 3'b001, 7'b0000000, "SLLI");
        add(7'b0010011, 3'b101, 7'b0000000, "SRLI");
        add(7'b0010011, 3'b101, 7'b0100000, "SRAI");
        // Stores placed before loads so data memory has known non-zero values (3)
        add(7'b0100011, 3'b000, 7'b0000000, "SB");
        add(7'b0100011, 3'b001, 7'b0000000, "SH");
        add(7'b0100011, 3'b010, 7'b0000000, "SW");
        // Data memory loads (5)
        add(7'b0000011, 3'b000, 7'b0000000, "LB");
        add(7'b0000011, 3'b001, 7'b0000000, "LH");
        add(7'b0000011, 3'b010, 7'b0000000, "LW");
        add(7'b0000011, 3'b100, 7'b0000000, "LBU");
        add(7'b0000011, 3'b101, 7'b0000000, "LHU");
        // Conditional branches (6)
        add(7'b1100011, 3'b000, 7'b0000000, "BEQ");
        add(7'b1100011, 3'b001, 7'b0000000, "BNE");
        add(7'b1100011, 3'b100, 7'b0000000, "BLT");
        add(7'b1100011, 3'b101, 7'b0000000, "BGE");
        add(7'b1100011, 3'b110, 7'b0000000, "BLTU");
        add(7'b1100011, 3'b111, 7'b0000000, "BGEU");
        // Jumps and upper-immediate instructions (4)
        add(7'b1101111, 3'b000, 7'b0000000, "JAL");
        add(7'b1100111, 3'b000, 7'b0000000, "JALR");
        add(7'b0110111, 3'b000, 7'b0000000, "LUI");
        add(7'b0010111, 3'b000, 7'b0000000, "AUIPC");
    endfunction

    // Sends one instruction to the driver mailbox and advances the expected PC word index
    task send(riscv_trans t);
        gen2driv.put(t);
        count++;
    endtask

    // Inserts an ADDI x0, x0, 0 NOP instruction
    task send_nop();
        riscv_trans n;
        n = new();
        n.set_pc(count * 4);
        n.make_nop();
        send(n);
    endtask

    task main();
        int         z_imm;
        riscv_trans t;
        bit [6:0] t_op;
        bit [2:0] t_f3;
        bit [6:0] t_f7;
        bit [4:0] t_rd;
        bit       t_has_f3, t_has_f7, t_same, is_br, is_cf;
        int       reps;

        count = 0;

        // Phase 0: Preload x1..x31 with random 32-bit values using LUI + ADDI pairs
        if (init_regs) begin
            for (int r = 1; r < 32; r++) begin
                t_rd = r;
                t = new(); t.set_pc(count * 4); t.name = "INIT_LUI";
                if (!t.randomize() with { opcode == 7'b0110111; rd == t_rd; })
                    $fatal(1, "[GENERATOR] init LUI randomization failed");
                send(t);

                t = new(); t.set_pc(count * 4); t.name = "INIT_ADDI";
                if (!t.randomize() with { opcode == 7'b0010011; funct3 == 3'b000;
                                          rd == t_rd; rs1 == t_rd; })
                    $fatal(1, "[GENERATOR] init ADDI randomization failed");
                send(t);
            end
        end
        
        // Phase 0b: Clear data memory bytes 0..63 so early loads read deterministic zeros
        for (int w = 0; w < 16; w++) begin
            z_imm = w * 4;
            t = new(); t.set_pc(count * 4); t.name = "INIT_SW";
            if (!t.randomize() with { opcode == 7'b0100011; funct3 == 3'b010;
                                      rs1 == 5'd0; rs2 == 5'd0; imm == z_imm; })
                $fatal(1, "[GENERATOR] init SW randomization failed");
            send(t);
        end

        // Phase 1: Directed test executing every one of the 37 RV32I instructions
        for (int i = 0; i < n_dir; i++) begin
            t_op = d_op[i]; t_f3 = d_f3[i]; t_f7 = d_f7[i];
            is_br    = (t_op == 7'b1100011);
            is_cf    = is_br || (t_op == 7'b1101111) || (t_op == 7'b1100111);
            t_has_f3 = !(t_op == 7'b1101111 || t_op == 7'b0110111 || t_op == 7'b0010111);
            t_has_f7 = (t_op == 7'b0110011) ||
                       (t_op == 7'b0010011 && (t_f3 == 3'b001 || t_f3 == 3'b101));
            // Run each branch twice: first with rs1 == rs2 to guarantee equal-case coverage, then random
            reps = is_br ? 2 : 1;

            for (int rp = 0; rp < reps; rp++) begin
                t_same = is_br && (rp == 0);
                t = new();
                t.set_pc(count * 4);
                t.name     = d_name[i];
                t.directed = 1;
                if (!t.randomize() with {
                        opcode == t_op;
                        (t_has_f3) -> (funct3 == t_f3);
                        (t_has_f7) -> (funct7 == t_f7);
                        (t_same)   -> (rs1 == rs2);
                    })
                    $fatal(1, "[GENERATOR] Directed randomization failed for %s", d_name[i]);
                send(t);
                // Insert a sacrificial NOP after branches/jumps so forward skips never bypass a real test instruction
                if (is_cf) send_nop();
            end
        end

        // Phase 2: Constrained-random instruction stream for corner-case stress testing
        for (int i = 0; i < random_count; i++) begin
            t = new();
            t.set_pc(count * 4);
            if (!t.randomize())
                $fatal(1, "[GENERATOR] Random-phase randomization failed");
            send(t);
        end
        -> ended;
    endtask
endclass

`endif
