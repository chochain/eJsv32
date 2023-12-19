//
// eJ32 - Java Forth Machine
//
// Chen-hanson Ting, 20220110 eJsv32k.v in Quartus II SystemVerilog-2005
// Chochain Lee      20220209 to eJ32 for Lattice and future versions
// Chochain Lee      20230216 consolidate ALU modules, tiddy macro tasks
//
`include "../source/eJ32_if.sv"
`include "../source/eJ32.vh"

`define PHASE0 phase_w = 0

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
    input logic            clk, rst,
    input logic [7:0]      data_i,
       
    // instruction
    output logic [7:0]     code_o,
    output logic [2:0]     phase_o,
    output logic [ASZ-1:0] p_o, a_o,
    // data stack       
    output logic [DSZ-1:0] t_o, s_o,
    output logic [SSZ-1:0] sp_o,
    // return stack
    output logic [DSZ-1:0] r_o,
    output logic [RSZ-1:0] rp_o,
    // IO
    output logic [ASZ-1:0] addr_o,
    output logic [7:0]     data_o,
    output logic           dwe_o
    );
    /// @defgroup Registers
    /// @{
    // instruction
    opcode_t       code;                  ///> JVM opcode
    logic[2:0]     phase;                 ///> FSM phase (aka state)
    logic[ASZ-1:0] p, a;                  ///> program counter, instruction pointer
    // data stack
    logic[DSZ-1:0] t, s;                  ///> TOS, NOS
    logic[DSZ-1:0] ss[SS_DEPTH-1:0];      ///> data stack, 3K LUTs, TODO: use EBR memory
    logic[SSZ-1:0] sp;                    ///> data stack pointers, sp1 = sp + 1
    // return stack
    logic[DSZ-1:0] rs[RS_DEPTH-1:0];      ///> return stack, 3K LUTs, TODO: use EBR memory
    logic[DSZ-1:0] r;                     ///> top of return stack
    logic[RSZ-1:0] rp;                    ///> return stack pointers
    // IO
    logic[ASZ-1:0] addr;                  ///> address
    logic[7:0]     data;                  ///> data
    logic[ASZ-1:0] ibuf, obuf;            ///> input, output buffer pointers
    logic          asel;                  ///> address bus mux (P|A)
    logic[1:0]     dsel;                  ///> 32-bit, 4-to-1 mux, byte select
    /// @}
    /// @defgroup Wires
    /// @{
    // instruction
    opcode_t       code_w;                ///> JVM opcode
    logic[2:0]     phase_w;               ///> FSM phase (aka state)
    logic[ASZ-1:0] p_w, a_w;              ///> program counter, instruction pointer
    logic          code_x;                ///> instruction unit control
    logic[ASZ-1:0] a_d;                   ///> combine address + data
    logic          p_x, a_x;              ///> address controls
    // data stack
    logic[DSZ-1:0] t_w;                   ///> TOS, NOS
    logic          t_x, t_z, t_neg;       ///> TOS controls
    logic[DSZ-1:0] t_d;                   ///> combined t & data
    logic[SSZ-1:0] sp1;                   ///> data stack pointers, sp1 = sp + 1
    logic          s_x, spush, spop;      ///> data stack controls
    // return stack
    logic[DSZ-1:0] r_w;                   ///> top of return stack
    logic[RSZ-1:0] rp1;                   ///> return stack pointers
    logic          r_x, rpush, rpop;      ///> return stack controls
    // IO
    logic          asel_w;                ///> address bus mux (P|A)
    logic[1:0]     dsel_w;                ///> 32-bit, 4-to-1 mux, byte select
    logic          dwe, dsel_x;           ///> data/addr bus controls
    logic          ibuf_x, obuf_x;        ///> input/output buffer controls
    /// @}
    /// @defgroup ALU pre-calc wires
    /// @{
    logic[DSZ-1:0] isht_o, iushr_o;
    logic          shr_f;
    logic[(DSZ*2)-1:0] mul_v;
    logic[DSZ-1:0] div_q, div_r;
    logic          div_rst, div_by_z, div_bsy;
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
    task STEP(input logic[2:0] n); phase_w = n; `CLR(code_x);  endtask;
    task WAIT(input logic[2:0] n); STEP(n); `CLR(p_x);         endtask;
    // data stack
    task TOS(input logic[DSZ-1:0] v);  t_w = v; `SET(t_x);     endtask;
    task ALU(input logic[DSZ-1:0] v);  TOS(v);  `SET(spop);    endtask;
    task PUSH(input logic[DSZ-1:0] v); TOS(v);  `SET(spush);   endtask;
    task POP();                        TOS(s);  `SET(spop);    endtask;
    // branching
    // Note: address is memory offset (instead of Java class file reference)
    task SETA(input logic[ASZ-1:0] a); a_w = a; `SET(a_x);     endtask;   /* build addr ptr    */
    task JMP(input logic[ASZ-1:0] a);  p_w = a; `SET(p_x);     endtask;   /* jmp and clear a   */
    task ZBRAN(input logic f);
        case (phase)
        0: begin STEP(1); SETA(`X8A(data_i)); end
        1: begin STEP(2); POP(); if (f) JMP(a_d); end
        default: `PHASE0;
        endcase
    endtask: ZBRAN
    task IBRAN(input logic f);
        case (phase)
        0: begin STEP(1); ALU(s - t); SETA(`X8A(data_i)); end
        1: begin STEP(2); POP(); if (f) JMP(a_d); end    /* pop off s; jmp */
        default: `PHASE0;
        endcase
    endtask: IBRAN
    // memory unit
    task MEM(input logic[ASZ-1:0] a);  SETA(a); `SET(asel_w); endtask;   /* fetch from memory, data_i returns next cycle */
    task DW(input logic[1:0] n); dsel_w = n; `SET(dwe); `SET(dsel_x); endtask;
    // external
    task DIV(input logic[DSZ-1:0] v);
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
        phase_w   = '0;           /// phase and IO controls
        code_x    = '1;
        p_x       = '1;
        p_w       = p + '1;       /// advance program counter
        // data stack
        t_w       = {DSZ{'0}};    /// TOS
        t_x       = '0;
        s_x       = '0;           /// data stack
        spush     = '0;
        spop      = '0;
        // return stack
        r_x       = '0;
        r_w       = {DSZ{'0}};    /// return stack
        rpush     = '0;
        rpop      = '0;
        // IO
        asel_w    = '0;
        a_w       = {ASZ{'0}};    /// address
        dsel_w    = 3;            /// data byte select
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
        if (!$cast(code_w, data_i)) begin
            /// JVM opcodes, some are not avialable yet
            code_w = op_err;
        end
*/
    endtask: SET_INIT
    /// IO
    assign s        = ss[sp];                 ///> data stack, TODO: EBR
    assign r        = rs[rp];                 ///> return stack, TODO: EBR
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
        istore_0: begin r_w = t; `SET(r_x); POP(); end  // CC: not tested
        iastore:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(s)); `SET(spop); `SET(dsel_x); dsel_w = 0; end
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
            2: begin WAIT(3); POP(); DW(3); asel_w = '1; end
            */
            0: begin WAIT(1); MEM(`XDA(s)); `SET(spop); `SET(dsel_x); dsel_w = 2; end
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
        dup_x1:                     // CC: logic changed since a_w is 16-bit only
            case (phase)
            0: begin WAIT(1); PUSH(s); end
            1: WAIT(2);             // wait for stack update??
            default: `PHASE0;
            endcase
        dup_x2: PUSH(ss[sp - 1]);
        dup2:                       // CC: logic changed since a_w is 16-bit only 
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
            // 0: begin phase_w = 1; MEM(s); end
            // 1: begin phase_w = 2; `HOLD; ALU(t + data_i); asel_w = 1'b1; end
            // default: begin `PHASE0; `HOLD; TOS(s); DW(0); end
            // CC: change Dr. Ting's logic
            0: begin WAIT(1); MEM(`XDA(s)); end
            1: begin WAIT(2); ALU(t + `X8D(data_i)); `SET(asel_w); end
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
            // 0: begin phase_w = 1; MEM(t); end
            // 1: begin phase_w = 2; `HOLD; MEM(a + 1); TOS(data_i); end
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
            0: begin STEP(1); SETA(`X8A(data_i)); r_w = `XAD(p) + 2; `SET(rpush); end
            1: begin STEP(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        donext:
            case (phase)
            0: begin STEP(1); SETA(`X8A(data_i)); end
            1: begin STEP(2);
               if (r == 0) begin `SET(rpop); end
               else begin
                  r_w = r - 1; `SET(r_x);
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
        pushr:begin POP(); r_w = t; `SET(rpush); end
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
            phase <= phase_w;
            asel  <= asel_w;
            // instruction ptr
            if (code_x)    code <= code_w;
            if (p_x)       p    <= p_w;
            if (a_x)       a    <= a_w;
            // data stack
            if (t_x)       t    <= t_w;
            if      (s_x)  ss[sp] <= t;
            else if (spop)  begin sp <= sp - 1; end
            else if (spush) begin ss[sp1] <= t; sp <= sp + 1; end   // CC: ERROR -> EBR with multiple writers
//            else if (spush) begin ss[sp] <= t; sp <= sp + 1; end  // CC: use this to fix synthesizer
            // return stack
            if (r_x)       rs[rp] <= r_w;
            else if (rpop)  begin rp <= rp - 1; end
            else if (rpush) begin rs[rp1] <= r_w; rp <= rp + 1; end
            // input/output buffer
            if (ibuf_x)    ibuf <= ibuf + 1;
            if (obuf_x)    obuf <= obuf + 1;
            if (dsel_x)    dsel <= dsel_w;
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
        if (phase_w==1) begin
            if (!div_bsy) begin
                $write("ERR: %8x %c %8x => %8x..%8x", s, op, t, div_q, div_w);
                assert(phase_w == 0) else begin
                    $write(", phase_w=%d reset =0", phase_w) ;
                    phase <= 0;
                end
                assert(cload == 1) else begin
                    $write(", cload=%d code_w=%s, p=%4x forced +1", cload, code_w.name, p);
                    code <= code_w; p <= p + 1;
                end
                assert(spop == 1) else begin
                    $write(", sp=%d, sp1=%d forced -1", sp, sp1);
                    sp <= sp - 1; sp1 <= sp1 - 1;
                end
                assert(t_w == (t_w==(idiv ? div_q : div_r))) else begin
                    $write(", tload=%d t_w=%8x =q/r", tload, t_w);
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
