//
// eJ32 - Java Forth Machine - Arithmetic Unit
//
`include "../source/eJ32_if.sv"

`define S(op) ss_op=op

module EJ32_AU #(
    parameter SS_DEPTH = 32,    ///> 32 deep data stack
    parameter DSZ      = 32     ///> 32-bit data width
    ) (
    EJ32_CTL ctl,
    input    `U1 au_en,         ///> arithmetic unit enable
    input    `U8 data,          ///> 8-bit data from memory bus
    output   `U1 div_bsy_o,
    output   `DU s_o
    );
    import ej32_pkg::*;
    /// @defgroup Registers
    /// @{
    stack_op ss_op;             ///> stack opcode
    `DU ss[SS_DEPTH];           ///> data stack, 3K LUTs, TODO: use EBR memory
    `DU t_n;                    ///> next TOS
    /// @}
    /// @defgroup Wires
    /// @{
    opcode_t code;              ///> shadow ctl.code
    `U3 phase;                  ///> FSM phase (aka state)
    `DU t, s;                   ///> shadow TOS, NOS
    `U1 t_x;                    ///> TOS update flag
    `DU t_d;                    ///> 4-byte merged data
    `U5 sp, sp1;                ///> data stack pointers, sp1 = sp + 1
    /// @}
    /// @defgroup ALU pre-calc wires
    /// @{
    `DU  isht_o, iushr_o;
    `U1  shr_f;
    `DU2 mul_v;
    `U1  div_en, div_bsy;
    `DU  div_q, div_r;
    `U1  div_by_z;
    ///
    /// extended ALU units
    ///
    mult      mult_inst(
    .a(t),
    .b(s),
    .r(mul_v)
    );
    div_int   div_inst(
    .clk(ctl.clk),
    .rst(~div_en),
    .x(s),
    .y(t),
    .busy(div_bsy),
    .dbz(div_by_z),
    .q(div_q),
    .r(div_r)
    );
    shifter   shifter_inst(
    .d(s),
    .dir(shr_f),
    .bits(t[4:0]),
    .r(isht_o)
    );
    ushifter  ushifter_inst(
    .d(s),
    .bits(t[4:0]),
    .r(iushr_o)
    );
    // data stack
    task TOS(input `DU v);  t_n = v; `SET(t_x); endtask;
    task ALU(input `DU v);  TOS(v); `S(sPOP);   endtask;
    task PUSH(input `DU v); TOS(v); `S(sPUSH);  endtask;
    task POP();             TOS(s); `S(sPOP);   endtask;
    task IBRAN();
        case (phase)
        0: ALU(s - t);
        1: POP();
        endcase
    endtask: IBRAN
    task ZBRAN(); if (phase==1) POP(); endtask;
    task DIV();  if (phase==1 && !div_bsy) ALU(div_q); endtask;
    task STOR(int n);
       if (phase==0) `S(sPOP);
       else if (phase==n) POP();
    endtask: STOR
    ///
    /// wires to reduce verbosity
    ///
    assign code   = ctl.code;               ///> input from ej32 control
    assign phase  = ctl.phase;
    assign t      = ctl.t;                  ///> shadow TOS from control bus
    assign s      = ss[sp];                 ///> data stack, TODO: EBR
    assign t_d    = {t[DSZ-9:0], data};     ///> merge lowest byte into TOS
    assign sp1    = sp + 1;
    assign div_en = (code==idiv || code==irem);
    /// wired to output
    assign div_bsy_o = div_bsy;
    assign s_o    = s;
    ///
    /// combinational
    ///
    task INIT();
        t_n   = {DSZ{1'b0}};  /// TOS
        t_x   = 1'b0;
        ss_op = sNOP;         /// data stack
        ///
        /// external module control flags
        ///
        shr_f = 1'b0;         /// shifter flag
    endtask: INIT

    always_comb begin
        INIT();
        ///
        /// instruction dispatcher
        ///
        case (code)
        // constant => TOS
        aconst_null: PUSH(0);
        iconst_m1:   PUSH(-1);
        iconst_0:    PUSH(0);
        iconst_1:    PUSH(1);
        iconst_2:    PUSH(2);
        iconst_3:    PUSH(3);
        iconst_4:    PUSH(4);
        iconst_5:    PUSH(5);
        // data => TOS
        bipush: if (phase==0) PUSH(`X8D(data));
        sipush:                     // CC: not tested
            case (phase)
            0: PUSH(`X8D(data));
            1: TOS(t_d);
            endcase
        // rs => TOS
        iload:     `S(sPUSH);       // CC: not tested
        iload_0:   `S(sPUSH);       // CC: not tested
        iload_1:   `S(sPUSH);       // CC: not tested
        iload_2:   `S(sPUSH);       // CC: not tested
        iload_3:   `S(sPUSH);       // CC: not tested
        // LS ops (TOS => memory bus)
        istore_0:  POP();
        iastore:   STOR(4);
        bastore:   STOR(1);
        sastore:   STOR(2);
        // stack ops
        pop:       POP();
        pop2:      POP();
        dup:       `S(sPUSH);
        dup_x1:    if (phase==0) PUSH(s);  // CC: logic changed since a_n is 16-bit only
        dup_x2:    PUSH(ss[sp - 1]);
        dup2:                              // CC: logic changed since a_n is 16-bit only 
            case (phase)
            0: PUSH(s);
            2: PUSH(s);
            endcase
        swap:      begin TOS(s); `S(sMOVE); end
        // arithmetic ops
        iadd:      ALU(s + t);
        isub:      ALU(s - t);
        imul:      ALU(mul_v[DSZ-1:0]);
        idiv:      DIV();
        irem:      DIV();
        ineg:      ALU(0 - t);
        ishl:      ALU(isht_o);
        ishr:      begin ALU(isht_o); `SET(shr_f); end
        iushr:     ALU(iushr_o);
        iand:      ALU(s & t);
        ior:       ALU(s | t);
        ixor:      ALU(s ^ t);
        iinc:      if (phase==1) ALU(t + `X8D(data));
        // BR conditional branching (feeds AU/TOS result to BR)
        ifeq:      ZBRAN();
        ifne:      ZBRAN();
        iflt:      ZBRAN();
        ifge:      ZBRAN();
        ifgt:      ZBRAN();
        ifle:      ZBRAN();
        if_icmpeq: IBRAN();
        if_icmpne: IBRAN();
        if_icmplt: IBRAN();
        if_icmpgt: IBRAN();
        // BR unconditional branching
        jsr:       if (phase==2) `S(sPUSH);
        // eForth VM specific
        dupr:      `S(sPUSH);
        popr:      `S(sPUSH);
        pushr:     POP();
        ldi:       if (phase==0) PUSH(`X8D(data));
        get:       if (phase==0) `S(sPUSH);
        put:       if (phase==1) POP();
        endcase
    end // always_comb
    ///
    /// data stacks
    ///
    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (ctl.rst) begin
            sp <= '0;
        end
        else if (ctl.clk && au_en) begin
            if (t_x) ctl.t <= t_n;
            // data stack
            case (ss_op)
            sMOVE: ss[sp] <= t;
            sPOP:  sp <= sp - 1;
            sPUSH: begin ss[sp1] <= t; sp <= sp + 1; end // CC: ERROR -> EBR with multiple writers
//          sPUSH: begin ss[sp] <= t; sp <= sp + 1; end  // CC: use this to fix synthesizer
            endcase
            ///
            /// validate and patch
            /// CC: do not know why DIV is skipping the branch
            ///
            if (div_en) div_patch();
        end
    end

    task div_patch();
        automatic `U8 op = code==idiv ? "/" : "%";
        if (phase==0) begin
            if (!div_bsy) begin
                $write("ERR: %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
                assert(ss_op == sPOP) else begin
                    $write(", sp=%d, sp1=%d forced -1", sp, sp1);
                    sp <= sp - 1;
                end
                assert(t_n == (t_n==(idiv ? div_q : div_r))) else begin
                    $write(", t_x=%d t_n=%8x =q/r", t_x, t_n);
                    ctl.t <= code==idiv ? div_q : div_r;
                end
            end
        end
        else begin // done div_int
            $display("OK %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
            assert(div_q == (s / t));
            assert(div_r == (s % t));
        end
    endtask: div_patch
endmodule: EJ32_AU
