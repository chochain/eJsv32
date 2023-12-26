//
// eJ32 - Java Forth Machine
//
// Chen-hanson Ting, 20220110 eJsv32k.v in Quartus II SystemVerilog-2005
// Chochain Lee      20220209 to eJ32 for Lattice and future versions
// Chochain Lee      20230216 consolidate ALU modules, tiddy macro tasks
// Chochain Lee      20231216 modulization
//
`include "../source/eJ32.vh"
`include "../source/eJ32_if.sv"

`define PHASE0 phase_n = 0
`define R(op)  ctl.rs_op = op
`define S(op)  ctl.ss_op = op

module ej32_core #(
    parameter TIB      = 'h1000,          ///> input buffer address
    parameter OBUF     = 'h1400,          ///> output buffer address
    parameter DSZ      = 32,              ///> 32-bit data width
    parameter ASZ      = 17,              ///> 128K address space
    parameter SS_DEPTH = 32,              ///> 32 deep data stack
    parameter RS_DEPTH = 32               ///> 32 deep return stack
    ) (
    ej32_ctl ctl,
    input  `U8 data_i,                    ///> data from memory bus
    output `IU addr_o,                    ///> address to memory bus
    output `U8 data_o,                    ///> data to memory bus
    output `U1 dwe_o                      ///> data write enable
    );
    import ej32_pkg::*;
    /// @defgroup Registers
    /// @{
    // instruction
    `U3  phase;                 ///> FSM phase (aka state)
    `IU  p, a;                  ///> program counter, instruction pointer
    // data stack
    `DU  s;                     ///> NOS
    `DU  ss[SS_DEPTH];          ///> data stack, 3K LUTs, TODO: use EBR memory
    `U5  sp;                    ///> data stack pointers, sp1 = sp + 1
    // return stack
    `DU  r;                     ///> top of RS
    `DU  rs[RS_DEPTH];          ///> return stack, 3K LUTs, TODO: use EBR memory
    `U5  rp;                    ///> return stack pointers
    // IO
    `U8  data;
    `IU  ibuf, obuf;            ///> input, output buffer pointers
    `U1  asel;                  ///> address bus mux (P|A)
    `U2  dsel;                  ///> 32-bit, 4-to-1 mux, byte select
    /// @}
    /// @defgroup Next Register
    /// @{
    // instruction
    opcode_t code_n;            ///> JVM opcode
    `U3 phase_n;                ///> FSM phase (aka state)
    `IU p_n, a_n;               ///> program counter, instruction pointer
    // data stack
    `DU t_n;                    ///> TOS
    // return stack
    `DU r_n;                    ///> top of return stack
    // IO
    `U8 data_n;
    `U1 asel_n;                 ///> address bus mux (P|A)
    `U2 dsel_n;                 ///> 32-bit, 4-to-1 mux, byte select
    /// @}
    /// @defgroup Wires
    /// @{
    // instruction
    opcode_t code;              ///> shadow ctl.code
    `U1 code_x;                 ///> instruction unit control
    `U1 p_x, a_x;               ///> address controls
    `IU a_d;                    ///> 2-byte merged address
    // data stack
    `DU t;                      ///> shadow TOS
    `U1 t_x, t_z, t_neg;        ///> TOS controls
    `DU t_d;                    ///> 4-byte merged data
    `U5 sp1;                    ///> data stack pointers, sp1 = sp + 1
    `U1 s_x;                    ///> data stack controls
    // return stack
    `U5 rp1;                    ///> return stack pointers
    `U1 r_x;                    ///> return stack controls
    // IO
    `U8 d8x4[4];                ///> 4-to-1 byte select
    `U1 dwe, dsel_x;            ///> data/addr bus controls
    `U1 ibuf_x, obuf_x;         ///> input/output buffer controls
    /// @}
    /// @defgroup ALU pre-calc wires
    /// @{
    `DU  isht_o, iushr_o;
    `U1  shr_f;
    `DU2 mul_v;
    `DU  div_q, div_r;
    `U1  div_rst, div_by_z, div_bsy;
    ///
    /// extended ALU units
    ///
    mult      mult_inst(
    .a(t),
    .b(s),
    .r(mul_v)
    );
    div_int   divide_inst(
    .clk(ctl.clk),
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
    task STEP(input `U3 n); phase_n = n; `CLR(code_x); endtask;
    task WAIT(input `U3 n); STEP(n); `CLR(p_x);        endtask;
    // data stack
    task TOS(input `DU v);  t_n = v; `SET(t_x); endtask;
    task ALU(input `DU v);  TOS(v); `S(sPOP);   endtask;
    task PUSH(input `DU v); TOS(v); `S(sPUSH);  endtask;
    task POP();             TOS(s); `S(sPOP);   endtask;
    // branching
    // Note: address is memory offset (instead of Java class file reference)
    //
    task SETA(input `IU a); a_n = a; `SET(a_x); endtask;   // build addr ptr
    task JMP(input `IU a);  p_n = a; `SET(a_x); endtask;   // jmp and clear a
    task ZBRAN(input `U1 f);
        case (phase)
        0: begin STEP(1); SETA(data); end
        1: begin STEP(2); POP(); if (f) JMP(a_d); end
        default: `PHASE0;
        endcase
    endtask: ZBRAN
    task IBRAN(input `U1 f);
        case (phase)
        0: begin STEP(1); SETA(data); ALU(s - t); end
        1: begin STEP(2); POP(); if (f) JMP(a_d); end      // pop off s; jmp
        default: `PHASE0;
        endcase
    endtask: IBRAN
    // memory unit
    task MEM(input `IU a); SETA(a); `SET(asel_n); endtask;  // fetch from memory, data returns next cycle
    task DW(input `U3 n); dsel_n = n; `SET(dwe); `SET(dsel_x); endtask;   // data write n-th byte
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
    /// wires to reduce verbosity
    ///
    assign s      = ss[sp];                   ///> data stack, TODO: EBR
    assign r      = rs[rp];                   ///> return stack, TODO: EBR
    assign sp1    = sp + 1;
    assign rp1    = rp + 1;
    ///
    /// IO signals wires
    ///
    assign code     = ctl.code;               ///> input from ej32 control
    assign t        = ctl.t;
    assign t_z      = ctl.t_z;
    assign t_neg    = ctl.t_neg;
    assign addr_o   = (asel) ? a : p;         ///> address, data or instruction
    assign data     = data_i;                 ///> data from memory bus
    assign data_o   = data_n;                 ///> data sent to memory bus
    assign dwe_o    = dwe;                    ///> data write enable
    assign d8x4     =                         ///> 4-to-1 Big-Endian
        {t[31:24],t[23:16],t[15:8],t[7:0]};
    assign data_n   = d8x4[dsel];             ///> data byte select (Big-Endian)
    ///
    /// wires to external modules
    ///
    assign div_rst= (code!=idiv && code!=irem) ? '1 : phase==0;
    assign a_d    = {a[ASZ-9:0], data};       ///> merge lowest byte into addr
    assign t_d    = {t[DSZ-9:0], data};       ///> merge lowest byte into TOS
    ///
    /// combinational
    ///
    task INIT();
        code_x    = 1'b1;         /// fetch opcode by default
        a_n       = {ASZ{1'b0}};  /// default to clear address
        a_x       = 1'b0;
        asel_n    = 1'b0;         /// address default to program counter
        p_n       = p + 'h1;      /// advance program counter
        p_x       = 1'b1;         /// advance PC by default
        t_n       = {DSZ{1'b0}};  /// TOS
        t_x       = 1'b0;
        r_n       = {DSZ{1'b0}};  /// return stack
        dsel_x    = 1'b0;         /// data bus
        dsel_n    = 3;
        dwe       = 1'b0;         /// data write
        ///
        /// external module control flags
        ///
        shr_f     = 1'b0;         /// shifter flag

        if (!$cast(code_n, data)) begin
            /// JVM opcodes, some are not avialable yet
            code_n = op_err;
        end

        phase_n   = 3'b0;         /// phase and IO controls
        ibuf_x    = 1'b0;
        obuf_x    = 1'b0;
    endtask: INIT
    task INIT_STACKS();
        `S(sNOP);
        `R(sNOP);
    endtask: INIT_STACKS
    always_comb begin
        INIT();
        INIT_STACKS();
        ///
        /// instruction dispatcher
        ///
        case (code)
        nop        : begin end  // do nothing
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
            0: begin STEP(1); PUSH(`X8D(data)); end
            default: `PHASE0;
            endcase
        sipush:                          // CC: not tested
            case (phase)
            0: begin STEP(1); PUSH(`X8D(data)); end
            1: begin STEP(2); TOS(t_d); end
            default: `PHASE0;
            endcase
        iload:   PUSH(rs[rp - data]);    // CC: not tested
        iload_0: PUSH(rs[rp]);           // CC: not tested
        iload_1: PUSH(rs[rp - 1]);       // CC: not tested
        iload_2: PUSH(rs[rp - 2]);       // CC: not tested
        iload_3: PUSH(rs[rp - 3]);       // CC: not tested
        iaload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); MEM(a + 1); TOS(`X8D(data)); end
            2: begin WAIT(3); MEM(a + 1); TOS(t_d); end
            3: begin WAIT(4); MEM(a + 1); TOS(t_d); end
            4: begin WAIT(5); TOS(t_d); end
            default: `PHASE0;
            endcase
        baload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t));    end
            1: begin WAIT(2); TOS(`X8D(data)); end
            default: `PHASE0;
            endcase
        saload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); MEM(a + 1); TOS(`X8D(data)); end
            2: begin WAIT(3); TOS(t_d); end
            default: `PHASE0;
            endcase
        istore_0: begin r_n = t; `R(sMOVE); POP(); end  // CC: not tested
        iastore:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(s)); `S(sPOP); `SET(dsel_x); dsel_n = 0; end
            1: begin WAIT(2); MEM(a + 1); DW(1); end
            2: begin WAIT(3); MEM(a + 1); DW(2); end
            3: begin WAIT(4); MEM(a + 1); DW(3); end
            4: begin WAIT(5); DW(3); POP(); end         // CC: reset a?
            default: `PHASE0;
            endcase
        bastore:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(s)); `S(sPOP); end
            1: begin WAIT(2); POP(); DW(3); end         // CC: reset a?
            default: `PHASE0;       // CC: extra cycle
            endcase
        sastore:
            case (phase)
            // CC: logic changed
            // 0: begin WAIT(1); MEM(s); `SET(spop); end
            // 1: begin WAIT(2); MEM(a + 1); DW(2); end
            // 2: begin WAIT(3); POP(); DW(3); `SET(asel_n); end
            0: begin WAIT(1); MEM(`XDA(s)); `S(sPOP); `SET(dsel_x); dsel_n = 2; end
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
        dup: `S(sPUSH);
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
        swap: begin TOS(s); `S(sMOVE); end
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
            // 1: begin phase_n = 2; `HOLD; ALU(t + data); asel_n = 1'b1; end
            // default: begin `PHASE0; `HOLD; TOS(s); DW(0); end
            // CC: change Dr. Ting's logic
            0: begin WAIT(1); MEM(`XDA(s)); end
            1: begin WAIT(2); ALU(t + `X8D(data)); `SET(asel_n); end
            default: begin `PHASE0; TOS(s); DW(0); end
            endcase // case (phase)
        //
        // conditional branching ops
        // Logical ops
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
        // branching
        //
        goto:
            case (phase)
            0: begin STEP(1); SETA(`X8A(data)); end // set addr higher byte
            1: begin STEP(2); JMP(a_d); end         // merge addr lower byte
            default: `PHASE0;
            endcase
        jsr:
            case (phase)
            // 0: begin phase_n = 1; MEM(t); end
            // 1: begin phase_n = 2; `HOLD; MEM(a + 1); TOS(data); end
            // CC: change Dr. Ting's logic
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); MEM(a + 1); TOS(`X8D(data)); end
            default: begin `PHASE0; JMP(`XDA(t_d)); PUSH(`XAD(p) + 2); end
            endcase
        ret: JMP(`XDA(r));
        jreturn:
            case (phase)
            0: begin STEP(1); `R(sPOP); JMP(`XDA(r)); end
            default: `PHASE0;
            endcase
        invokevirtual:
            case (phase)
            0: begin STEP(1); SETA(`X8A(data)); r_n = `XAD(p) + 2; `R(sPUSH); end
            1: begin STEP(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        donext:
            case (phase)
            0: begin STEP(1); SETA(`X8A(data)); end
            1: begin STEP(2);
               if (r == 0) begin `R(sPOP); end
               else begin
                  r_n = r - 1; `R(sMOVE);
                  JMP(a_d);
               end
            end
            default: `PHASE0;
            endcase
        ldi:
            case (phase)
            0: begin STEP(1); PUSH(`X8D(data)); end
            1: begin STEP(2); TOS(t_d); end
            2: begin STEP(3); TOS(t_d); end
            3: begin STEP(4); TOS(t_d); end
            default: `PHASE0;
            endcase
        popr: begin PUSH(r); `R(sPOP); end
        pushr:begin POP(); r_n = t; `R(sPUSH); end
        dupr: PUSH(r);
        get:
            case (phase)
            0: begin WAIT(1); MEM(ibuf); `S(sPUSH); end
            1: begin WAIT(2); TOS(`X8D(data)); `SET(ibuf_x); end
            default: `PHASE0;     // CC: extra memory cycle
            endcase
        put:
            case (phase)
            0: begin WAIT(1); MEM(obuf); `SET(dsel_x); end
            default: begin `PHASE0; POP(); DW(3); `SET(obuf_x); end
            endcase
        default: `PHASE0;
        endcase
    end // always_comb
    ///
    /// data & return stacks
    ///
    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (ctl.rst) begin
            sp    <= '0;
            rp    <= '0;
        end
        else if (ctl.clk) begin
            // data stack
            case (ctl.ss_op)
            sMOVE: ss[sp] <= t;
            sPOP:  sp <= sp - 1;
            sPUSH: begin ss[sp1] <= t; sp <= sp + 1; end // CC: ERROR -> EBR with multiple writers
//          sPUSH: begin ss[sp] <= t; sp <= sp + 1; end  // CC: use this to fix synthesizer
            endcase
            // return stack
            case (ctl.rs_op)
            sMOVE: rs[rp] <= r_n;
            sPOP:  rp <= rp - 1;
            sPUSH: begin rs[rp1] <= r_n; rp <= rp + 1; end
            endcase
        end
    end
    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (ctl.rst) begin
            phase <= 3'b0;
            asel  <= 1'b0;
            dsel  <= 3;
            ibuf  <= TIB;
            obuf  <= OBUF;
            a     <= {ASZ{1'b0}};
            p     <= {ASZ{1'b0}};
        end
        else if (ctl.clk) begin
            phase <= phase_n;
            asel  <= asel_n;
            // instruction
            if (code_x)    ctl.code <= code_n;
            if (t_x)       ctl.t    <= t_n;
            if (p_x)       p    <= p_n;
            if (a_x)       a    <= a_n;
            // memory
            if (dsel_x)    dsel <= dsel_n;
            if (ibuf_x)    ibuf <= ibuf + 1;
            if (obuf_x)    obuf <= obuf + 1;
            ///
            /// validate and patch
            /// CC: do not know why DIV is skipping the branch
            ///
            if (!div_rst) div_patch();
        end
    end // always_ff @ (posedge clk, posedge rst)

    task div_patch();
        automatic `U8 op = code==idiv ? "/" : "%";
        if (phase_n==1) begin
            if (!div_bsy) begin
                $write("ERR: %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
                assert(phase_n == 0) else begin
                    $write(", phase_n=%d reset =0", phase_n) ;
                    phase <= 0;
                end
                assert(code_x == 1) else begin
                    $write(", code_x=%d code_n=%s, p=%4x forced +1", code_x, code_n.name, p);
                    ctl.code <= code_n; p <= p + 1;
                end
                assert(ctl.ss_op == sPOP) else begin
                    $write(", sp=%d, sp1=%d forced -1", sp, sp1);
                    sp <= sp - 1;
                end
                assert(t_n == (t_n==(idiv ? div_q : div_r))) else begin
                    $write(", t_x=%d t_n=%8x =q/r", t_x, t_n);
                    ctl.t <= code==idiv ? div_q : div_r;
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
endmodule: ej32_core
