//
// eJ32 - Java Forth Machine - Arithmetic Unit
//
`include "../source/eJ32_if.sv"

`define S(op) ss_op=op

module EJ32_AU #(
    parameter DSZ = 32          ///> 32-bit data width
    ) (
    EJ32_CTL ctl,
    input    `U1 au_en,         ///> arithmetic unit enable
    input    `U8 data,          ///> 8-bit data from memory bus
    output   `U1 div_bsy_o,
    output   `DU s_o,
    output   `DU au_t_o,        ///> output for arbitation
    output   `U1 au_t_x
    );
    import ej32_pkg::*;
    /// @defgroup Registers
    /// @{
    stack_op ss_op;             ///> stack opcode
    `DU t_n;                    ///> next TOS
    `DU s_n;
    /// @}
    /// @defgroup Wires
    /// @{
    opcode_t code;              ///> shadow ctl.code
    `U3 phase;                  ///> FSM phase (aka state)
    `DU t, s;                   ///> shadow TOS, NOS
    `U1 t_x;                    ///> TOS update flag
    `DU t_d;                    ///> 4-byte merged data
    `DU d2t;                    ///> convert 8-bit data to 32-bit
    `SU sp;                     ///> data stack pointer
    /// @}
    /// @defgroup EBR control
    /// @{
    `U1 ss_ren;
    `U1 ss_wen;
    `SU sp_r;
    `SU sp_w;
    `U1 s_x;
    /// @}
    /// @defgroup ALU pre-calc wires
    /// @{
    `DU  isht_o, iushr_o;
    `U1  shr_f;
    `DU2 mul_v;
    `U1  div_en, div_bsy;
    `DU  div_q, div_r;
    `U1  div_z;
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
    .z(div_z),
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
    ///
    /// data stack (using embedded block memory)
    ///
    bram_dp #() ss(
        .wr_clk_i(~ctl.clk),    ///> leads half a cycle 
        .rd_clk_i(~ctl.clk),
        .rst_i(ctl.rst),
        .wr_clk_en_i(1'b1),
        .rd_clk_en_i(1'b1),
        .rd_en_i(ss_ren),
        .wr_en_i(ss_wen),
        .wr_data_i(t),
        .wr_addr_i(sp_w),
        .rd_addr_i(sp_r),
        .rd_data_o(s_n)        ///> read back into NOS
    );
    // data stack tasks (as macros)
    task TOS(input `DU v); t_n = v; `SET(t_x); endtask               ///> update TOS
    task ALU(input `DU v); TOS(v); sp_r = sp - 1; `S(sPOP); endtask  ///> t <= v, drop NOS
    task LOAD(); ss_wen = 1'b1; `S(sPUSH); endtask                   ///> sp_r = sp, sp_w = sp + 1
    task PUSH(input `DU v);
        TOS(v);                
        ss_wen = 1'b1;         ///> default sp_r = sp; sp_w = sp + 1 (i.e. s <= ss[sp + 1])
        s_x    = 1'b0;         ///> current cycle: s <= t (s_o no need to wait one extra cycle)
        `S(sPUSH);
    endtask: PUSH
    task POP(); ALU(s); endtask                                      ///> replace TOS with NOS
    task IBRAN();              ///> conditional branch
        case (phase)
        0: ALU(s - t);
        1: POP();
        endcase
    endtask: IBRAN
    task ZBRAN();          if (phase==1) POP();                 endtask
    task STOR(int n);      if (phase==n || phase==(n+1)) POP(); endtask
    task DIV(input `DU v); if (phase==1 && !div_bsy) ALU(v);    endtask
    ///
    /// wires to reduce verbosity
    ///
    assign code   = ctl.code;               ///> input from ej32 control
    assign phase  = ctl.phase;
    assign t      = ctl.t;                  ///> shadow TOS from control bus
    assign t_d    = {t[DSZ-9:0], data};     ///> merge lowest byte into TOS
    assign div_en = (code==idiv || code==irem) && phase!=0;  // wait 1 cycle for TOS
    assign d2t    = `X8D(data);
    ///
    /// wired to output
    ///
    assign div_bsy_o = div_bsy;
    assign s_o    = (s_x) ? s_n : t;
    assign au_t_o = t_n;
    assign au_t_x = t_x;
    ///
    /// combinational
    ///
    task INIT();
        t_n   = t;
        t_x   = 1'b0;
        ss_op = sNOP;         /// data stack
        ss_ren= 1'b1;
        ss_wen= 1'b0;
        sp_w  = sp + 1;
        sp_r  = sp;
        s_x   = 1'b1;         /// use ss return
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
        bipush: if (phase==0) PUSH(d2t);
        sipush:                     // CC: not tested
            case (phase)
            0: PUSH(d2t);
            1: TOS(t_d);
            endcase
        // rs => TOS
        iload:     LOAD();       // CC: not tested
        iload_0:   LOAD();       // CC: not tested
        iload_1:   LOAD();       // CC: not tested
        iload_2:   LOAD();       // CC: not tested
        iload_3:   LOAD();       // CC: not tested
        // LS ops (TOS => memory bus)
        istore_0:  POP();
        iastore:   STOR(4);
        bastore:   STOR(1);
        sastore:   STOR(2);
        // stack ops
        pop:       POP();
        pop2:      POP();
        dup:       PUSH(t);
        dup_x1:    if (phase==0) PUSH(s); // CC: logic changed since a_n is 16-bit only 
        /* dup_x2:  PUSH(ss[sp - 1]); */  // CC: not tested, skip for now
        dup2:                             // CC: logic changed since a_n is 16-bit only 
            case (phase)
            0: PUSH(s);
            2: PUSH(s);
            endcase
        swap:      begin           ///> s <= t, t <= s (in one cycle), ss_op = sNOP
            TOS(s);
            ss_wen = 1'b1;
            sp_r   = sp - 1;
            sp_w   = sp;           ///> update NOS (and read in next cycle)
            s_x    = 1'b0;         ///> s <= t (update s directly in current cycle)
        end
        // arithmetic ops
        iadd:      ALU(s + t);
        isub:      ALU(s - t);
        imul:      ALU(mul_v[DSZ-1:0]);
        idiv:      DIV(div_q);
        irem:      DIV(div_r);
        ineg:      ALU(0 - t);
        ishl:      ALU(isht_o);
        ishr:      begin ALU(isht_o); `SET(shr_f); end
        iushr:     ALU(iushr_o);
        iand:      ALU(s & t);
        ior:       ALU(s | t);
        ixor:      ALU(s ^ t);
        iinc:      if (phase==1) ALU(t + d2t);
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
        jsr:       if (phase==2) LOAD();
        // eForth VM specific
        dupr:      begin LOAD(); s_x = 1'b0; end        ///> load from return stack
        popr:      begin LOAD(); s_x = 1'b0; end        ///> load from return stack
        pushr:     POP();
        ldi:       if (phase==0) PUSH(d2t);
        get:       if (phase==0) LOAD();
        put:       if (phase==1) POP();
        endcase
    end // always_comb
    ///
    /// data stacks
    ///
    always_ff @(posedge ctl.clk) begin
        if (ctl.rst) begin
            sp <= '0;
        end
        else if (au_en) begin
            s  <= s_x ? s_n : t;
            // data stack
            case (ss_op)
            sPOP:  sp <= sp - 1;
            sPUSH: sp <= sp + 1;
            endcase
            ///
            /// verify divider
            ///
            if (div_en && !div_bsy) div_check();
         end
    end

    task div_check();
        automatic `U8 op  = code==idiv ? "/" : "%";
        case (phase)
        1: begin             // done div_int
            assert(div_q == (s / t) && div_r == (s % t)) else begin
                $display("AU.1.ERR %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
            end
        end
        endcase
    endtask: div_check
endmodule: EJ32_AU
