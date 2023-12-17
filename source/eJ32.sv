//
// eJ32 - Java Forth Machine
//
// Chen-hanson Ting, 20220110 eJsv32k.v in Quartus II SystemVerilog-2005
// Chochain Lee      20220209 to eJ32 for Lattice and future versions
// Chochain Lee      20230216 consolidate ALU modules, tiddy macro tasks
//
`include "../source/eJ32_if.sv"
`include "../source/eJ32.vh"

`define PHASE0 phase_in = 0
`define SET(v) v = 1'b1
`define CLR(v) v = 1'b0
`define X8A(b) {9'b0,b}
`define X8D(b) {24'b0,b}
`define XAD(a) {15'b0,a}
`define XDA(d) d[ASZ-1:0]

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
    input logic [7:0]      data_o_i,
    // instruction
    output logic [7:0]     code_o,
    output logic [2:0]     phase_o,
    output logic [ASZ-1:0] p_o, a_o,
    // data stack       
    output logic [DSZ-1:0] t_o, s_o,
    output logic [SSZ-1:0] sp_o,
    // return stack
    output logic [RSZ-1:0] rp_o,
    // IO
    output logic [ASZ-1:0] addr_o_o,
    output logic [7:0]     data_o_o,
    output logic           dwe_o
    );
    /// @defgroup Registers
    /// @{
    // instruction
    opcode         code;                  ///> JVM opcode
    logic[2:0]     phase;                 ///> FSM phase (aka state)
    logic[ASZ-1:0] p, a;                  ///> program counter, instruction pointer
    logic          asel;                  ///> address bus mux (P|A)
    // data stack
    logic[DSZ-1:0] ss[SS_DEPTH-1:0];      ///> data stack, 3K LUTs, TODO: use EBR memory
    logic[SSZ-1:0] sp, sp1;               ///> data stack pointers, sp1 = sp + 1
    logic[DSZ-1:0] t, s;                  ///> TOS, NOS
    // return stack
    logic[DSZ-1:0] rs[RS_DEPTH-1:0];      ///> return stack, 3K LUTs, TODO: use EBR memory
    logic[RSZ-1:0] rp, rp1;               ///> return stack pointers
    logic[DSZ-1:0] r;                     ///> top of return stack
    // IO
    logic[ASZ-1:0] addr_o;                ///> address
    logic[7:0]     data_o;                ///> data
    logic[ASZ-1:0] ibuf, obuf;            ///> input, output buffer pointers
    logic[1:0]     dsel;                  ///> 32-bit, 4-to-1 mux, byte select
    /// @}
    /// @defgroup Wires
    /// @{
    // instruction
    opcode         code_in;
    logic          cload;                           ///> instruction unit control
    logic[2:0]     phase_in;
    logic[ASZ-1:0] p_in, a_in, a_d;                 ///> program counter, instruction ptr
    logic          pload, aload;                    ///> address controls
    // data stack
    logic          tload, t_z, sload, spush, spop;  ///> data stack controls
    logic[DSZ-1:0] t_in, r_in, t_d;                 ///> TOS controls
    // return stack
    logic          rload, rpush, rpop;              ///> return stack controls
    // IO
    logic          ibufload, obufload;              ///> input/output buffer controls
    logic          asel_in;                         ///> addr select
    logic[7:0]     data_i;                          ///> input/output data
    logic[1:0]     dsel_in;                         ///> data select mux
    logic          dwe, dselload;                   ///> data/addr bus controls
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
    task NXPH(input logic[2:0] n); phase_in = n; `CLR(cload); endtask;
    task BUSY(input logic[2:0] n); NXPH(n); `CLR(pload);      endtask;
    //
    // Note: address is memory offset (instead of Java class file reference)
    //
    task SETA(input logic[ASZ-1:0] a); a_in = a; `SET(aload);   endtask;   /* build addr ptr    */
    task MEM(input logic[ASZ-1:0] a);  SETA(a);  `SET(asel_in); endtask;   /* fetch from memory, data_i returns next cycle */
    task JMP(input logic[ASZ-1:0] a);  p_in = a; `SET(aload);   endtask;   /* jmp and clear a   */

    task TOS(input logic[DSZ-1:0] v);  t_in = v; `SET(tload);   endtask;
    task PUSH(input logic[DSZ-1:0] v); TOS(v); `SET(spush);     endtask;
    task POP();                        TOS(s); `SET(spop);      endtask;
    task ALU(input logic[DSZ-1:0] v);  TOS(v); `SET(spop);       endtask;
    task DW(input logic[1:0] n); dsel_in = n; `SET(dwe); `SET(dselload); endtask;

    task DIV(input logic[DSZ-1:0] v);
        case (phase)
        0: BUSY(1);
        default: begin
            if (div_bsy) BUSY(1);
            else begin `PHASE0; ALU(v); end
        end
        endcase
    endtask: DIV

    task ZBRAN(input logic f);
        case (phase)
        0: begin NXPH(1); SETA(`X8A(data_i)); end
        1: begin NXPH(2); POP(); if (f) JMP(a_d); end
        default: `PHASE0;
        endcase
    endtask; // ZBRAN

    task IBRAN(input logic f);
        case (phase)
        0: begin NXPH(1); ALU(s - t); SETA(`X8A(data_i)); end
        1: begin NXPH(2); POP(); if (f) JMP(a_d); end    /* pop off s; jmp */
        default: `PHASE0;
        endcase
    endtask; // IBRAN
    ///
    /// wires to reduce verbosity
    ///
    // instruction
    assign code_o   = code;                   ///> JVM opcode
    assign phase_o  = phase;                  ///> multi-step instruction
    assign p_o      = p;                      ///> program counter
    assign a_o      = a;                      ///> instruction pointer
    assign a_d      = {a[ASZ-9:0], data_i};   ///> shift combined address
    // data stack   
    assign t_o      = t;
    assign t_d      = {t[DSZ-9:0], data_i};   ///> shift combined t (top of stack)
    assign t_z      = t == 0;                 ///> TOS zero flag
    assign s        = ss[sp];                 ///> data stack, TODO: EBR
    assign s_o      = s;
    assign sp_o     = sp;
    assign sp1      = sp + 1;
    // return stack
    assign r        = rs[rp];                 ///> return stack, TODO: EBR
    assign rp_o     = rp;
    assign rp1      = rp + 1;
    /// IO
    assign addr_o_o = addr_o;
    assign addr_o   = (asel) ? a : p;         /// address, data or instruction
    assign data_i   = data_o_i;
    assign data_o_o = data_o;
    assign dwe_o    = dwe;
    assign data_o   = (dsel == 3)             // data byte select (Big-Endian)
                    ? t[7:0]
                    : (dsel == 2)
                        ? t[15:8]
                        : (dsel == 1)
                            ? t[23:16]
                            : t[31:24];
    // external module
    assign div_rst= (code!=idiv && code!=irem) ? 1'b1 : phase==0;
    ///
    /// combinational
    ///
    always_comb begin
        // instruction
        phase_in  = 0;            /// phase and IO controls
        cload     = 1'b1;
        pload     = 1'b1;
        p_in      = p + 'h1;      /// advance program counter
        // data stack
        tload     = 1'b0;
        t_in      = {DSZ{1'b0}};  /// TOS
        sload     = 1'b0;         /// data stack
        spush     = 1'b0;
        spop      = 1'b0;
        // return stack
        rload     = 1'b0;
        r_in      = {DSZ{1'b0}};  /// return stack
        rpush     = 1'b0;
        rpop      = 1'b0;
        // IO
        aload     = 1'b0;
        a_in      = {ASZ{1'b0}};  /// address
        asel_in   = 1'b0;
        ibufload  = 1'b0;
        obufload  = 1'b0;
        dwe       = 1'b0;         /// data write enable
        dselload  = 1'b0;         /// data bus
        dsel_in   = 3;            /// data byte select
        ///
        /// external module control flags
        ///
        shr_f     = 1'b0;         /// shifter flag
/*
        if (!$cast(code_in, data_i)) begin
            /// JVM opcodes, some are not avialable yet
            code_in = op_err;
        end
*/
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
            0: begin NXPH(1); PUSH(`X8D(data_i)); end
            default: `PHASE0;
            endcase
        sipush:                          // CC: not tested
            case (phase)
            0: begin NXPH(1); PUSH(`X8D(data_i)); end
            1: begin NXPH(2); TOS(t_d); end
            default: `PHASE0;
            endcase
        iload:   PUSH(rs[rp - data_i[RSZ-1:0]]);  // CC: not tested
        iload_0: PUSH(rs[rp]);           // CC: not tested
        iload_1: PUSH(rs[rp - 1]);       // CC: not tested
        iload_2: PUSH(rs[rp - 2]);       // CC: not tested
        iload_3: PUSH(rs[rp - 3]);       // CC: not tested
        iaload:
            case (phase)
            0: begin BUSY(1); MEM(`XDA(t)); end
            1: begin BUSY(2); MEM(a + 1); TOS(`X8D(data_i)); end
            2: begin BUSY(3); MEM(a + 1); TOS(t_d); end
            3: begin BUSY(4); MEM(a + 1); TOS(t_d); end
            4: begin BUSY(5); TOS(t_d); end
            default: `PHASE0;
            endcase
        baload:
            case (phase)
            0: begin BUSY(1); MEM(`XDA(t)); end
            1: begin BUSY(2); TOS(`X8D(data_i)); end
            default: `PHASE0;
            endcase
        saload:
            case (phase)
            0: begin BUSY(1); MEM(`XDA(t)); end
            1: begin BUSY(2); MEM(a + 1); TOS(`X8D(data_i)); end
            2: begin BUSY(3); TOS(t_d); end
            default: `PHASE0;
            endcase
        istore_0: begin r_in = t; `SET(rload); POP(); end  // CC: not tested
        iastore:
            case (phase)
            0: begin BUSY(1); MEM(`XDA(s)); `SET(spop); `SET(dselload); dsel_in = 0; end
            1: begin BUSY(2); MEM(a + 1); DW(1); end
            2: begin BUSY(3); MEM(a + 1); DW(2); end
            3: begin BUSY(4); MEM(a + 1); DW(3); end
            4: begin BUSY(5); DW(3); POP(); end
            default: `PHASE0;
            endcase
        bastore:
            case (phase)
            0: begin BUSY(1); MEM(`XDA(s)); `SET(spop); end
            1: begin BUSY(2); POP(); DW(3); end
            default: `PHASE0;       // CC: extra cycle
            endcase
        sastore:
            case (phase)
            /* CC: logic changed
            0: begin BUSY(1); MEM(s); spop = 1'b1; end
            1: begin BUSY(2); MEM(a + 1); DW(2); end
            2: begin BUSY(3); POP(); DW(3); asel_in = 1'b1; end
            */
            0: begin BUSY(1); MEM(`XDA(s)); `SET(spop); `SET(dselload); dsel_in = 2; end
            1: begin BUSY(2); MEM(a + 1); DW(3); end
            2: begin BUSY(3); DW(3); POP(); end
            default: `PHASE0;
            endcase
        pop: POP();
        pop2:
            case (phase)
            0: begin BUSY(1); POP(); end
            default: begin `PHASE0; POP(); end
            endcase
        dup: `SET(spush);
        dup_x1:                     // CC: logic changed since a_in is 16-bit only
            case (phase)
            0: begin BUSY(1); PUSH(s); end
            1: BUSY(2);             // wait for stack update??
            default: `PHASE0;
            endcase
        dup_x2: PUSH(ss[sp - 1]);
        dup2:                       // CC: logic changed since a_in is 16-bit only 
            case (phase)
            0: begin BUSY(1); PUSH(s); end
            1: BUSY(2);             // CC: wait for stack update??
            2: begin BUSY(3); PUSH(s); end
            default: `PHASE0;
            endcase
        swap: begin TOS(s); `SET(sload); end
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
            // 0: begin phase_in = 1; MEM(s); end
            // 1: begin phase_in = 2; `HOLD; ALU(t + data_i); asel_in = 1'b1; end
            // default: begin `PHASE0; `HOLD; TOS(s); DW(0); end
            // CC: change Dr. Ting's logic
            0: begin BUSY(1); MEM(`XDA(s)); end
            1: begin BUSY(2); ALU(t + `X8D(data_i)); `SET(asel_in); end
            default: begin `PHASE0; TOS(s); DW(0); end
            endcase
        //
        // conditional branching ops
        //
        ifeq:      ZBRAN(t_z);
        ifne:      ZBRAN(!t_z);
        iflt:      ZBRAN(t[DSZ-1]);
        ifge:      ZBRAN(!t[DSZ-1]);
        ifgt:      ZBRAN(!t_z && !t[DSZ-1]);
        ifle:      ZBRAN(t_z || t[DSZ-1]);
        if_icmpeq: IBRAN(t_z);
        if_icmpne: IBRAN(!t_z);
        if_icmplt: IBRAN(t[DSZ-1]);
        if_icmpgt: IBRAN(!t_z && !t[DSZ-1]);
        //
        // unconditional branching ops
        //
        goto:
            case (phase)
            0: begin NXPH(1); SETA(`X8A(data_i)); end
            1: begin NXPH(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        jsr:
            case (phase)
            // 0: begin phase_in = 1; MEM(t); end
            // 1: begin phase_in = 2; `HOLD; MEM(a + 1); TOS(data_i); end
            // CC: change Dr. Ting's logic
            0: begin BUSY(1); MEM(`XDA(t)); end
            1: begin BUSY(2); MEM(a + 1); TOS(`X8D(data_i)); end
            default: begin `PHASE0; JMP(`XDA(t_d)); PUSH(`XAD(p) + 2); end
            endcase
        ret: JMP(`XDA(r));
        jreturn:
            case (phase)
            0: begin NXPH(1); `SET(rpop); JMP(`XDA(r)); end
            default: `PHASE0;
            endcase
        invokevirtual:
            case (phase)
            0: begin NXPH(1); SETA(`X8A(data_i)); r_in = `XAD(p) + 2; `SET(rpush); end
            1: begin NXPH(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        donext:
            case (phase)
            0: begin NXPH(1); SETA(`X8A(data_i)); end
            1: begin NXPH(2);
               if (r == 0) begin `SET(rpop); end
               else begin
                  r_in = r - 1; `SET(rload);
                  JMP(a_d);
               end
            end
            default: `PHASE0;
            endcase // case (phase)
        // stack ops
        ldi:
            case (phase)
            0: begin NXPH(1); PUSH(`X8D(data_i)); end
            1: begin NXPH(2); TOS(t_d); end
            2: begin NXPH(3); TOS(t_d); end
            3: begin NXPH(4); TOS(t_d); end
            default: `PHASE0;
            endcase
        popr: begin PUSH(r); `SET(rpop); end
        pushr:begin POP(); r_in = t; `SET(rpush); end
        dupr: PUSH(r);
        // memory access ops
        get:
            case (phase)
            0: begin BUSY(1); MEM(ibuf); `SET(spush); end
            1: begin BUSY(2); TOS(`X8D(data_i)); `SET(ibufload); end
            default: `PHASE0;     // CC: extra memory cycle
            endcase
        put:
            case (phase)
            0: begin BUSY(1); MEM(obuf); `SET(dselload); end
            default: begin `PHASE0; POP(); DW(3); `SET(obufload); end
            endcase
        default: `PHASE0;
        endcase
    end
// registers
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            phase <= 3'b0;
            asel  <= 1'b0;
            dsel  <= 3;
            sp    <= 0;
            rp    <= 0;
            ibuf  <= TIB;
            obuf  <= OBUF;
            t     <= {DSZ{1'b0}};
            a     <= {ASZ{1'b0}};
            p     <= {ASZ{1'b0}};
        end
        else if (clk) begin
            phase <= phase_in;
            asel  <= asel_in;
            // instruction ptr
            if (cload)     code <= code_in;
            if (pload)     p    <= p_in;
            if (aload)     a    <= a_in;
            // data stack
            if (tload)     t    <= t_in;
            if      (sload) ss[sp] <= t;
            else if (spop)  begin sp <= sp - 1; end
            else if (spush) begin ss[sp1] <= t; sp <= sp + 1; end   // CC: ERROR -> EBR with multiple writers
//            else if (spush) begin ss[sp] <= t; sp <= sp + 1; sp1 <= sp1 + 1; end  // CC: use this to fix synthesizer
            // return stack
            if (rload)      rs[rp] <= r_in;
            else if (rpop)  begin rp <= rp - 1; end
            else if (rpush) begin rs[rp1] <= r_in; rp <= rp + 1; end
            // input/output buffer
            if (ibufload)  ibuf <= ibuf + 1;
            if (obufload)  obuf <= obuf + 1;
            if (dselload)  dsel <= dsel_in;
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
        if (phase_in==1) begin
            if (!div_bsy) begin
                $write("ERR: %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
                assert(phase_in == 0) else begin
                    $write(", phase_in=%d reset =0", phase_in) ;
                    phase <= 0;
                end
                assert(cload == 1) else begin
                    $write(", cload=%d code_in=%s, p=%4x forced +1", cload, code_in.name, p);
                    code <= code_in; p <= p + 1;
                end
                assert(spop == 1) else begin
                    $write(", sp=%d, sp1=%d forced -1", sp, sp1);
                    sp <= sp - 1; sp1 <= sp1 - 1;
                end
                assert(t_in == (t_in==(idiv ? div_q : div_r))) else begin
                    $write(", tload=%d t_in=%8x =q/r", tload, t_in);
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
