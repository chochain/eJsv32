//
// eJ32 - Java Forth Machine
//
// Chen-hanson Ting, 20220110 eJsv32k.v in Quartus II SystemVerilog-2005
// Chochain Lee      20220209 to eJ32 for Lattice and future versions
// Chochain Lee      20230216 consolidate ALU modules, tiddy macro tasks
//
`include "../source/eJ32_if.sv"
`include "../source/eJ32.vh"

`define PHASE0 phase_n = 0

module eJ32 #(
    parameter TIB      = 'h1000,          ///> input buffer address
    parameter OBUF     = 'h1400,          ///> output buffer address
    parameter DSZ      = 32,              ///> 32-bit data width
    parameter ASZ      = 17,              ///> 128K address space
    parameter SS_DEPTH = 32,              ///> 32 deep data stack
    parameter RS_DEPTH = 32,              ///> 32 deep return stack
    parameter SSZ = $clog2(SS_DEPTH),
    parameter RSZ = $clog2(RS_DEPTH)
    ) (
    input  `U1 clk, rst,
    input  `U8 data_i,

    // instruction
    output `U8 code_o,
    output `U3 phase_o,
    output `IU p_o, a_o,
    // data stack
    output `DU t_o, s_o,
    output `U5 sp_o,
    // return stack
    output `DU r_o,
    output `U5 rp_o,
    // IO
    output `IU addr_o,
    output `U8 data_o,
    output `U1 dwe_o
    );
    /// @defgroup Registers
    /// @{
    // instruction
    opcode_t code;       ///> JVM opcode
    `U3 phase;           ///> FSM phase (aka state)
    `IU p, a;            ///> program counter, instruction pointer
    // data stack
    `DU t, s;            ///> TOS, NOS
    `DU ss[SS_DEPTH];    ///> data stack, 3K LUTs, infer EBR memory
    `U5 sp;              ///> data stack pointers, sp1 = sp + 1
    // return stack
    `DU rs[RS_DEPTH];    ///> return stack, 3K LUTs, infer EBR memory
    `DU r;               ///> top of return stack
    `U5 rp;              ///> return stack pointers
    // IO
    `IU addr;            ///> address
    `U8 data;            ///> data
    `IU ibuf, obuf;      ///> input, output buffer pointers
    `U1 asel;            ///> address bus mux (P|A)
    `U2 dsel;            ///> 32-bit, 4-to-1 mux, byte select
    /// @}
    /// @defgroup Next Register
    /// @{
    // instruction
    opcode_t code_n;     ///> JVM opcode
    `U3 phase_n;         ///> FSM phase (aka state)
    `IU p_n, a_n;        ///> program counter, instruction pointer
    // data stack
    `DU t_n;             ///> TOS, NOS
    // return stack
    `DU r_n;             ///> top of return stack
    // IO
    `U1 asel_n;          ///> address bus mux (P|A)
    `U2 dsel_n;          ///> 32-bit, 4-to-1 mux, byte select
    /// @}
    /// @defgroup Wires
    /// @{
    // instruction
    `U1 code_x;                ///> instruction unit control
    `IU a_d;                   ///> combine address + data
    `U1 p_x, a_x;              ///> address controls
    // data stack
    `U1 t_x, t_z, t_neg;       ///> TOS controls
    `DU t_d;                   ///> combined t & data
    `U5 sp1;                   ///> data stack pointers, sp1 = sp + 1
    `U1 s_x, spush, spop;      ///> data stack controls
    // return stack
    `U5 rp1;                   ///> return stack pointers
    `U1 r_x, rpush, rpop;      ///> return stack controls
    // IO
    `U1 dwe, dsel_x;           ///> data/addr bus controls
    `U1 ibuf_x, obuf_x;        ///> input/output buffer controls
    /// @}
    /// @defgroup ALU pre-calc wires
    /// @{
    `DU isht_o, iushr_o;
    `U1 shr_f;
    `DU div_q, div_r;
    `U1 div_rst, div_by_z, div_bsy;
    `DU2 mul_v;
    ///
    /// extended ALU units
    ///
   /*
    mult      mult_inst(
    .a(t),
    .b(s),
    .r(mul_v)
    );
    div_int   divide_inst(
    .clk(clk),
    .rst(div_rst),
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
    */
    task STEP(input `U3 n); phase_n = n; `CLR(code_x);  endtask;
    task WAIT(input `U3 n); STEP(n); `CLR(p_x);         endtask;
    // data stack
    task TOS(input `DU v);  t_n = v; `SET(t_x);     endtask;
    task ALU(input `DU v);  TOS(v);  `SET(spop);    endtask;
    task PUSH(input `DU v); TOS(v);  `SET(spush);   endtask;
    task POP();                        TOS(s);  `SET(spop);    endtask;
    // branching
    // Note: address is memory offset (instead of Java class file reference)
    task SETA(input `IU a); a_n = a; `SET(a_x);     endtask;   /* build addr ptr    */
    task JMP(input `IU a);  p_n = a; `SET(p_x);     endtask;   /* jmp and clear a   */
    task ZBRAN(input `U1 f);
        case (phase)
        0: begin STEP(1); SETA(`X8A(data_i)); end
        1: begin STEP(2); POP(); if (f) JMP(a_d); end
        default: `PHASE0;
        endcase
    endtask: ZBRAN
    task IBRAN(input `U1 f);
        case (phase)
        0: begin STEP(1); ALU(s - t); SETA(`X8A(data_i)); end
        1: begin STEP(2); POP(); if (f) JMP(a_d); end    /* pop off s; jmp */
        default: `PHASE0;
        endcase
    endtask: IBRAN
    // memory unit
    task MEM(input `IU a);  SETA(a); `SET(asel_n); endtask;   /* fetch from memory, data_i returns next cycle */
    task DW(input `U2 n); dsel_n = n; `SET(dwe); `SET(dsel_x); endtask;
    // external
    task DIV(input `DU v);
        case (phase)
        0: WAIT(1);
        default: begin
            if (div_bsy) WAIT(1);
            else begin `PHASE0; ALU(v); end
        end
        endcase
    endtask: DIV
    ///
    ///> wire initial values
    ///
    task SET_INIT();
        // instruction
        phase_n   = '0;           /// phase and IO controls
        code_x    = '1;
        p_x       = '1;
        p_n       = p + '1;       /// advance program counter
        // data stack
        t_n       = {DSZ{'0}};    /// TOS
        t_x       = '0;
        s_x       = '0;           /// data stack
        spush     = '0;
        spop      = '0;
        // return stack
        r_n       = {DSZ{'0}};    /// return stack
        r_x       = '0;
        rpush     = '0;
        rpop      = '0;
        // IO
        asel_n    = '0;
        a_n       = {ASZ{'0}};    /// address
        dsel_n    = 3;            /// data byte select
        a_x       = '0;
        dsel_x    = '0;           /// data bus
        dwe       = '0;           /// data write enable
        ibuf_x    = '0;
        obuf_x    = '0;
        ///
        /// external module control flags
        ///
        shr_f     = '0;           /// shifter flag
/*
        if (!$cast(code_n, data_i)) begin
            /// JVM opcodes, some are not avialable yet
            code_n = op_err;
        end
*/
    endtask: SET_INIT
    /// IO
    assign s        = ss[sp];                ///> data stack, TODO: EBR
    assign r        = rs[rp];                ///> return stack, TODO: EBR
    assign addr     = (asel) ? a : p;        ///> address, data or instruction
    assign data     = (dsel == 3)            ///> data byte select (Big-Endian)
                    ? t[7:0]
                    : (dsel == 2)
                        ? t[15:8]
                        : (dsel == 1)
                            ? t[23:16]
                            : t[31:24];
    // external module
    assign div_rst= (code!=idiv && code!=irem) ? '1 : phase==0;
    ///
    /// output drivers
    ///
    always_comb begin
       // instruction
       code_o   = code;                   ///> JVM opcode
       phase_o  = phase;                  ///> multi-step instruction
       p_o      = p;                      ///> program counter
       a_o      = a;                      ///> instruction pointer
       a_d      = {a[ASZ-9:0], data_i};   ///> shift combined address
       // data stack
       t_o      = t;
       s_o      = s;
       sp_o     = sp;
       // return stack
       r_o      = r;
       rp_o     = rp;
       // IO
       addr_o   = addr;
       data_o   = data;
       dwe_o    = dwe;
    end // always_comb
    ///
    /// wires to reduce verbosity
    ///
    always_comb begin
       t_d      = {t[DSZ-9:0], data_i};   ///> shift combined t (top of stack)
       t_z      = t == 0;                 ///> TOS zero flag
       t_neg    = t[DSZ-1];               ///> TOS negative flag
       sp1      = sp + 1;
       rp1      = rp + 1;
    end // always_comb
    ///
    /// combinational logic
    ///
    always_comb begin
        SET_INIT();
        ///
        /// instruction dispatcher
        ///
        case (code)
        nop        : begin /* do nothing */ end
        aconst_null: PUSH(0);
        iconst_m1  : PUSH(-1);
        iconst_0   : PUSH(0);
        iconst_1   : PUSH(1);
        iconst_2   : PUSH(2);
        iconst_3   : PUSH(3);
        iconst_4   : PUSH(4);
        iconst_5   : PUSH(5);
        bipush:
            case (phase)
            0: begin STEP(1); PUSH(`X8D(data_i)); end
            default: `PHASE0;
            endcase
        sipush:                          // CC: not tested
            case (phase)
            0: begin STEP(1); PUSH(`X8D(data_i)); end
            1: begin STEP(2); TOS(t_d); end
            default: `PHASE0;
            endcase
        iload:   PUSH(rs[rp - data_i[RSZ-1:0]]);  // CC: not tested
        iload_0: PUSH(rs[rp]);           // CC: not tested
        iload_1: PUSH(rs[rp - 1]);       // CC: not tested
        iload_2: PUSH(rs[rp - 2]);       // CC: not tested
        iload_3: PUSH(rs[rp - 3]);       // CC: not tested
        iaload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); MEM(a + 1); TOS(`X8D(data_i)); end
            2: begin WAIT(3); MEM(a + 1); TOS(t_d); end
            3: begin WAIT(4); MEM(a + 1); TOS(t_d); end
            4: begin WAIT(5); TOS(t_d); end
            default: `PHASE0;
            endcase
        baload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); TOS(`X8D(data_i)); end
            default: `PHASE0;
            endcase
        saload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); MEM(a + 1); TOS(`X8D(data_i)); end
            2: begin WAIT(3); TOS(t_d); end
            default: `PHASE0;
            endcase
        istore_0: begin r_n = t; `SET(r_x); POP(); end  // CC: not tested
        iastore:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(s)); `SET(spop); `SET(dsel_x); dsel_n = 0; end
            1: begin WAIT(2); MEM(a + 1); DW(1); end
            2: begin WAIT(3); MEM(a + 1); DW(2); end
            3: begin WAIT(4); MEM(a + 1); DW(3); end
            4: begin WAIT(5); DW(3); POP(); end
            default: `PHASE0;
            endcase
        bastore:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(s)); `SET(spop); end
            1: begin WAIT(2); POP(); DW(3); end
            default: `PHASE0;       // CC: extra cycle
            endcase
        sastore:
            case (phase)
            /* CC: logic changed
            0: begin WAIT(1); MEM(s); spop = '1; end
            1: begin WAIT(2); MEM(a + 1); DW(2); end
            2: begin WAIT(3); POP(); DW(3); asel_n = '1; end
            */
            0: begin WAIT(1); MEM(`XDA(s)); `SET(spop); `SET(dsel_x); dsel_n = 2; end
            1: begin WAIT(2); MEM(a + 1); DW(3); end
            2: begin WAIT(3); DW(3); POP(); end
            default: `PHASE0;
            endcase
        pop: POP();
        pop2:
            case (phase)
            0: begin WAIT(1); POP(); end
            default: begin `PHASE0; POP(); end
            endcase
        dup: `SET(spush);
        dup_x1:                     // CC: logic changed since a_n is 16-bit only
            case (phase)
            0: begin WAIT(1); PUSH(s); end
            1: WAIT(2);             // wait for stack update??
            default: `PHASE0;
            endcase
        dup_x2: PUSH(ss[sp - 1]);
        dup2:                       // CC: logic changed since a_n is 16-bit only 
            case (phase)
            0: begin WAIT(1); PUSH(s); end
            1: WAIT(2);             // CC: wait for stack update??
            2: begin WAIT(3); PUSH(s); end
            default: `PHASE0;
            endcase
        swap: begin TOS(s); `SET(s_x); end
        //
        // ALU ops
        //
        iadd: ALU(s + t);
        isub: ALU(s - t);
        imul: ALU(mul_v[DSZ-1:0]);
        idiv: DIV(div_q);
        irem: DIV(div_r);
        ineg: ALU(0 - t);
        ishl: ALU(isht_o);
        ishr: begin ALU(isht_o); `SET(shr_f); end
        iushr:ALU(iushr_o);
        iand: ALU(s & t);
        ior:  ALU(s | t);
        ixor: ALU(s ^ t);
        iinc:
            case (phase)
            // 0: begin phase_n = 1; MEM(s); end
            // 1: begin phase_n = 2; `HOLD; ALU(t + data_i); asel_n = 1'b1; end
            // default: begin `PHASE0; `HOLD; TOS(s); DW(0); end
            // CC: change Dr. Ting's logic
            0: begin WAIT(1); MEM(`XDA(s)); end
            1: begin WAIT(2); ALU(t + `X8D(data_i)); `SET(asel_n); end
            default: begin `PHASE0; TOS(s); DW(0); end
            endcase
        //
        // conditional branching ops
        //
        ifeq:      ZBRAN(t_z);
        ifne:      ZBRAN(!t_z);
        iflt:      ZBRAN(t_neg);
        ifge:      ZBRAN(!t_neg);
        ifgt:      ZBRAN(!t_z && !t_neg);
        ifle:      ZBRAN(t_z || t_neg);
        if_icmpeq: IBRAN(t_z);
        if_icmpne: IBRAN(!t_z);
        if_icmplt: IBRAN(t_neg);
        if_icmpgt: IBRAN(!t_z && !t_neg);
        //
        // unconditional branching ops
        //
        goto:
            case (phase)
            0: begin STEP(1); SETA(`X8A(data_i)); end
            1: begin STEP(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        jsr:
            case (phase)
            // 0: begin phase_n = 1; MEM(t); end
            // 1: begin phase_n = 2; `HOLD; MEM(a + 1); TOS(data_i); end
            // CC: change Dr. Ting's logic
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); MEM(a + 1); TOS(`X8D(data_i)); end
            default: begin `PHASE0; JMP(`XDA(t_d)); PUSH(`XAD(p) + 2); end
            endcase
        ret: JMP(`XDA(r));
        jreturn:
            case (phase)
            0: begin STEP(1); `SET(rpop); JMP(`XDA(r)); end
            default: `PHASE0;
            endcase
        invokevirtual:
            case (phase)
            0: begin STEP(1); SETA(`X8A(data_i)); r_n = `XAD(p) + 2; `SET(rpush); end
            1: begin STEP(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        donext:
            case (phase)
            0: begin STEP(1); SETA(`X8A(data_i)); end
            1: begin STEP(2);
               if (r == 0) begin `SET(rpop); end
               else begin
                  r_n = r - 1; `SET(r_x);
                  JMP(a_d);
               end
            end
            default: `PHASE0;
            endcase // case (phase)
        // stack ops
        ldi:
            case (phase)
            0: begin STEP(1); PUSH(`X8D(data_i)); end
            1: begin STEP(2); TOS(t_d); end
            2: begin STEP(3); TOS(t_d); end
            3: begin STEP(4); TOS(t_d); end
            default: `PHASE0;
            endcase
        popr: begin PUSH(r); `SET(rpop); end
        pushr:begin POP(); r_n = t; `SET(rpush); end
        dupr: PUSH(r);
        // memory access ops
        get:
            case (phase)
            0: begin WAIT(1); MEM(ibuf); `SET(spush); end
            1: begin WAIT(2); TOS(`X8D(data_i)); `SET(ibuf_x); end
            default: `PHASE0;     // CC: extra memory cycle
            endcase
        put:
            case (phase)
            0: begin WAIT(1); MEM(obuf); `SET(dsel_x); end
            default: begin `PHASE0; POP(); DW(3); `SET(obuf_x); end
            endcase
        default: `PHASE0;
        endcase // case (code)
    end
    // registers
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            phase <= '0;
            a     <= {ASZ{'0}};
            p     <= {ASZ{'0}};
            t     <= {DSZ{'0}};
            sp    <= '0;
            rp    <= '0;
            ibuf  <= TIB;
            obuf  <= OBUF;
            asel  <= '0;
            dsel  <= 3;
        end
        else if (clk) begin
            phase <= phase_n;
            asel  <= asel_n;
            // instruction ptr
            if (code_x)    code <= code_n;
            if (p_x)       p    <= p_n;
            if (a_x)       a    <= a_n;
            // data stack
            if (t_x)       t    <= t_n;
            if      (s_x)  ss[sp] <= t;
            else if (spop)  begin sp <= sp - 1; end
            else if (spush) begin ss[sp1] <= t; sp <= sp + 1; end   // CC: ERROR -> EBR with multiple writers
//          else if (spush) begin ss[sp] <= t; sp <= sp + 1; end  // CC: use this to fix synthesizer
            // return stack
            if (r_x)       rs[rp] <= r_n;
            else if (rpop)  begin rp <= rp - 1; end
            else if (rpush) begin rs[rp1] <= r_n; rp <= rp + 1; end
            // input/output buffer
            if (ibuf_x)    ibuf <= ibuf + 1;
            if (obuf_x)    obuf <= obuf + 1;
            if (dsel_x)    dsel <= dsel_n;
            ///
            /// validate and patch
            /// CC: do not know why DIV is skipping the branch
            ///
//            if (!div_rst) div_patch();
        end
    end // always_ff @ (posedge clk, posedge rst)
/*
    task div_patch();
        automatic logic[7:0] op = code==idiv ? "/" : "%";
        if (phase_n==1) begin
            if (!div_bsy) begin
                $write("ERR: %8x %c %8x => %8x..%8x", s, op, t, div_q, div_n);
                assert(phase_n == 0) else begin
                    $write(", phase_n=%d reset =0", phase_n) ;
                    phase <= 0;
                end
                assert(cload == 1) else begin
                    $write(", cload=%d code_n=%s, p=%4x forced +1", cload, code_n.name, p);
                    code <= code_n; p <= p + 1;
                end
                assert(spop == 1) else begin
                    $write(", sp=%d, sp1=%d forced -1", sp, sp1);
                    sp <= sp - 1; sp1 <= sp1 - 1;
                end
                assert(t_n == (t_n==(idiv ? div_q : div_r))) else begin
                    $write(", tload=%d t_n=%8x =q/r", tload, t_n);
                    t <= code==idiv ? div_q : div_r;
                end
                $display(" :ERR");
            end
        end
        else begin // done div_int
            $display("OK %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
            assert(div_q == (s / t));
            assert(div_r == (s % t));
        end
    endtask: div_patch
 */
endmodule
