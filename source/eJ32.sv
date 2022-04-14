//
// eJ32 - Java Forth Machine
//
// Chen-hanson Ting, 20220110 eJsv32k.v in Quartus II SystemVerilog-2005
// Chochain          20220209 to eJ32 for Lattice and future versions
//
`include "../source/forthsuper_if.sv"
`include "../source/eJ32.vh"

`define PHASE0 phase_in = 0

module eJ32 #(
    parameter TIB      = 'h1000,
    parameter OBUF     = 'h1400,
    parameter DSZ      = 32,     /* 32-bit data width  */
    parameter ASZ      = 17,     /* 128K address space */
    parameter SS_DEPTH = 32,
    parameter RS_DEPTH = 32,
    parameter SSZ = $clog2(SS_DEPTH),
    parameter RSZ = $clog2(RS_DEPTH)
    ) (
    input logic            clk, clr,
    input logic [7:0]      data_o_i,
    output logic [7:0]     data_o_o, code_o,
    output logic [DSZ-1:0] s_o, t_o,
    output logic [ASZ-1:0] addr_o_o, p_o, a_o,
    output logic [2:0]     phase_o,
    output logic [SSZ-1:0] sp_o,
    output logic [RSZ-1:0] rp_o,
    output logic           write_o
    );

// registers
    logic[DSZ-1:0] ss[SS_DEPTH-1:0];           // 3K LUTs, TODO: use EBR memory
    logic[DSZ-1:0] rs[RS_DEPTH-1:0];           // 3K LUTs, TODO: use EBR memory
    logic[SSZ-1:0] sp, sp1;
    logic[RSZ-1:0] rp, rp1;
    logic[DSZ-1:0] t;
    logic[ASZ-1:0] p, a;
    logic[ASZ-1:0] iptr, optr;                 // input, output buffer pointers
    logic[2:0]     phase;
    logic[1:0]     dsel;
    logic          asel;
    jvm_opcode     code;
// wires
    logic[DSZ-1:0] s, r;
    logic[DSZ-1:0] t_in, r_in, t_d;
    logic[ASZ-1:0] a_in, p_in, a_d, addr_o;
    logic          tload, t_z, sload, spush, spop;  // data stack controls
    logic          rload, rpush, rpop;              // return stack controls
    logic          aload, pload;                    // address controls
    logic          iload, oload;                    // IO controls
    logic[7:0]     data_i, data_o;
    logic[2:0]     phase_in;
    logic[1:0]     dsel_in;
    logic          write, asel_in, dselload, cload;
    logic[DSZ-1:0] isht_o, iushr_o;
    logic          shr_f;
    logic[(DSZ*2)-1:0] mul_v;
    logic[DSZ-1:0] div_q, div_r;
    logic          div_rst, div_by_z, div_bsy;
    jvm_opcode     code_in;

    mult  mult_inst (
    .dataa (t),
    .datab (s),
    .result (mul_v)
    );
    /*
    divide    divide_inst (
    .denom (t),
    .numer (s),
    .quotient (div_q),
    .remain (div_r)
    );
    */
    div_int   divide_inst (
    .clk(clk),
    .rst(div_rst),
    .x(s),
    .y(t),
    .busy(div_bsy),
    .dbz(div_by_z),
    .q(div_q),
    .r(div_r)
    );
    shifter   shifter_inst (
    .data (s),
    .direction (shr_f),
    .distance (t[4:0]),
    .result (isht_o)
    );
    ushifter  ushifter_inst (
    .data (s),
    .distance (t[4:0]),
    .result (iushr_o)
    );

    task nphase(input logic[2:0] n); phase_in = (n); cload = 1'b0; endtask;
    task nphold(input logic[2:0] n); nphase(n); pload = 1'b0;      endtask;
    //
    // Note: address is memory offset (instead of Java class file reference)
    //
    task SETA(input logic[ASZ-1:0] a); aload = 1'b1; a_in = (a);   endtask;   /* build addr ptr    */
    task MEM(input logic[ASZ-1:0] a);  SETA(a); asel_in = 1'b1;    endtask;   /* fetch from memory, data_i returns next cycle */
    task JMP(input logic[ASZ-1:0] a);  p_in = (a); aload = 1'b1;   endtask;   /* jmp and clear a   */

    task TOS(input logic[DSZ-1:0] v);  tload = 1'b1; t_in = (v);   endtask;
    task PUSH(input logic[DSZ-1:0] v); TOS(v); spush = 1'b1;       endtask;
    task POP();                        TOS(s); spop  = 1'b1;       endtask;
    task ALU(input logic[DSZ-1:0] v);  TOS(v); spop  = 1'b1;       endtask;
    task dwrite(input logic[2:0] n);   write = 1'b1; dselload = 1'b1; dsel_in = (n); endtask;

    task DIV(input logic[DSZ-1:0] v);
        case (phase)
        0: nphold(1);
        default: begin
            if (div_bsy) nphold(1);
            else begin `PHASE0; ALU(v); end
        end
        endcase
    endtask: DIV

    task ZBRAN(input logic f);
        case (phase)
        0: begin nphase(1); SETA(data_i); end
        1: begin nphase(2); POP(); if (f) JMP(a_d); end
        default: `PHASE0;
        endcase
    endtask; // ZBRAN

    task IBRAN(input logic f);
        case (phase)
        0: begin nphase(1); ALU(s - t); SETA(data_i); end
        1: begin nphase(2); POP(); if (f) JMP(a_d); end    /* pop off s; jmp */
        default: `PHASE0;
        endcase
    endtask; // IBRAN
    ///
    /// wires to reduce verbosity
    ///
    assign s      = ss[sp];
    assign r      = rs[rp];
    assign a_d    = {a[ASZ-9:0], data_i};     // shift combined address
    assign t_d    = {t[DSZ-9:0], data_i};     // shift combined t (top of stack)
    assign t_z    = t == 0;                   // TOS zero flag
    assign div_rst= (code!=idiv && code!=irem) ? 1'b1 : phase==0;
    ///
    /// IO signals wires
    ///
    assign data_i   = data_o_i;
    assign data_o_o = data_o;
    assign addr_o_o = addr_o;
    assign write_o  = write;
    assign code_o   = code;
    assign s_o      = s;
    assign t_o      = t;
    assign p_o      = p;
    assign a_o      = a;
    assign phase_o  = phase;
    assign sp_o     = sp;
    assign rp_o     = rp;
    assign addr_o = (asel) ? a : p;           // address, data or instruction
    assign data_o   = (dsel == 3)             // data byte select (Big-Endian)
                    ? t[7:0]
                    : (dsel == 2)
                        ? t[15:8]
                        : (dsel == 1)
                            ? t[23:16]
                            : t[31:24];
    ///
    /// combinational
    ///
    always_comb begin
        a_in      = {ASZ{1'b0}};  /// address
        aload     = 1'b0;
        asel_in   = 1'b0;
        p_in      = p + 'h1;      /// advance program counter
        pload     = 1'b1;
        cload     = 1'b1;
        t_in      = {DSZ{1'b0}};  /// TOS
        tload     = 1'b0;
        sload     = 1'b0;         /// data stack
        spush     = 1'b0;
        spop      = 1'b0;
        r_in      = {DSZ{1'b0}};  /// return stack
        rload     = 1'b0;
        rpush     = 1'b0;
        rpop      = 1'b0;
        dselload  = 1'b0;         /// data bus
        dsel_in   = 3;
        write     = 1'b0;         /// data write
        ///
        /// external module control flags
        ///
        shr_f     = 1'b0;         /// shifter flag

        if (!$cast(code_in, data_i)) begin
            /// JVM opcodes, some are not avialable yet
            code_in = op_err;
        end

        phase_in  = 0;            /// phase and IO controls
        iload     = 1'b0;
        oload     = 1'b0;
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
            0: begin nphase(1); PUSH(data_i); end
            default: `PHASE0;
            endcase
        sipush:                          // CC: not tested
            case (phase)
            0: begin nphase(1); PUSH(data_i); end
            1: begin nphase(2); TOS(t_d); end
            default: `PHASE0;
            endcase
        iload:   PUSH(rs[rp - data_i]);  // CC: not tested
        iload_0: PUSH(rs[rp]);           // CC: not tested
        iload_1: PUSH(rs[rp - 1]);       // CC: not tested
        iload_2: PUSH(rs[rp - 2]);       // CC: not tested
        iload_3: PUSH(rs[rp - 3]);       // CC: not tested
        iaload:
            case (phase)
            0: begin nphold(1); MEM(t); end
            1: begin nphold(2); MEM(a + 1); TOS(data_i); end
            2: begin nphold(3); MEM(a + 1); TOS(t_d); end
            3: begin nphold(4); MEM(a + 1); TOS(t_d); end
            4: begin nphold(5); TOS(t_d); end
            default: `PHASE0;
            endcase
        baload:
            case (phase)
            0: begin nphold(1); MEM(t); end
            1: begin nphold(2); TOS(data_i); end
            default: `PHASE0;
            endcase
        saload:
            case (phase)
            0: begin nphold(1); MEM(t); end
            1: begin nphold(2); MEM(a + 1); TOS(data_i); end
            2: begin nphold(3); TOS(t_d); end
            default: `PHASE0;
            endcase
        istore_0: begin r_in = t; rload = 1'b1; POP(); end  // CC: not tested
        iastore:
            case (phase)
            0: begin nphold(1); MEM(s); spop = 1'b1; dselload = 1'b1; dsel_in = 0; end
            1: begin nphold(2); MEM(a + 1); dwrite(1); end
            2: begin nphold(3); MEM(a + 1); dwrite(2); end
            3: begin nphold(4); MEM(a + 1); dwrite(3); end
            4: begin nphold(5); dwrite(3); POP(); end
            default: `PHASE0;
            endcase
        bastore:
            case (phase)
            0: begin nphold(1); MEM(s); spop = 1'b1; end
            1: begin nphold(2); POP(); dwrite(3); end
            default: `PHASE0;       // CC: extra cycle
            endcase
        sastore:
            case (phase)
            /* CC: logic changed
            0: begin nphold(1); MEM(s); spop = 1'b1; end
            1: begin nphold(2); MEM(a + 1); dwrite(2); end
            2: begin nphold(3); POP(); dwrite(3); asel_in = 1'b1; end
            */
            0: begin nphold(1); MEM(s); spop = 1'b1; dselload = 1'b1; dsel_in = 2; end
            1: begin nphold(2); MEM(a + 1); dwrite(3); end
            2: begin nphold(3); dwrite(3); POP(); end
            default: `PHASE0;
            endcase
        pop: POP();
        pop2:
            case (phase)
            0: begin nphold(1); POP(); end
            default: begin `PHASE0; POP(); end
            endcase
        dup: spush = 1'b1;
        dup_x1:                     // CC: logic changed since a_in is 16-bit only
            case (phase)
            0: begin nphold(1); PUSH(s); end
            1: nphold(2);           // wait for stack update??
            default: `PHASE0;
            endcase
        dup_x2: PUSH(ss[sp - 1]);
        dup2:                       // CC: logic changed since a_in is 16-bit only 
            case (phase)
            0: begin nphold(1); PUSH(s); end
            1: nphold(2);           // CC: wait for stack update??
            2: begin nphold(3); PUSH(s); end
            default: `PHASE0;
            endcase
        swap: begin TOS(s); sload = 1'b1; end
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
        ishr: begin ALU(isht_o); shr_f = 1'b1; end
        iushr:ALU(iushr_o);
        iand: ALU(s & t);
        ior:  ALU(s | t);
        ixor: ALU(s ^ t);
        iinc:
            case (phase)
            // 0: begin phase_in = 1; MEM(s); end
            // 1: begin phase_in = 2; `HOLD; ALU(t + data_i); asel_in = 1'b1; end
            // default: begin `PHASE0; `HOLD; TOS(s); dwrite(0); end
            // CC: change Dr. Ting's logic
            0: begin nphold(1); MEM(s); end
            1: begin nphold(2); ALU(t + data_i); asel_in = 1'b1; end
            default: begin `PHASE0; TOS(s); dwrite(0); end
            endcase
        //
        // Logical ops
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
        // branching
        //
        goto:
            case (phase)
            0: begin nphase(1); SETA(data_i); end
            1: begin nphase(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        jsr:
            case (phase)
            // 0: begin phase_in = 1; MEM(t); end
            // 1: begin phase_in = 2; `HOLD; MEM(a + 1); TOS(data_i); end
            // CC: change Dr. Ting's logic
            0: begin nphold(1); MEM(t); end
            1: begin nphold(2); MEM(a + 1); TOS(data_i); end
            default: begin `PHASE0; JMP(t_d); PUSH(p + 2); end
            endcase
        ret: JMP(r);
        jreturn:
            case (phase)
            0: begin nphase(1); rpop = 1'b1; JMP(r); end
            default: `PHASE0;
            endcase
        invokevirtual:
            case (phase)
            0: begin nphase(1); SETA(data_i); r_in = p + 2; rpush = 1'b1; end
            1: begin nphase(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        donext:
            case (phase)
            0: begin nphase(1); SETA(data_i); end
            1: begin nphase(2);
               if (r == 0) begin rpop = 1'b1; end
               else begin
                  r_in = r - 1; rload = 1'b1;
                  JMP(a_d);
               end
            end
            default: `PHASE0;
            endcase
        ldi:
            case (phase)
            0: begin nphase(1); PUSH(data_i); end
            1: begin nphase(2); TOS(t_d); end
            2: begin nphase(3); TOS(t_d); end
            3: begin nphase(4); TOS(t_d); end
            default: `PHASE0;
            endcase
        popr: begin PUSH(r); rpop = 1'b1; end
        pushr:begin POP(); r_in = t; rpush = 1'b1; end
        dupr: PUSH(r);
        get:
            case (phase)
            0: begin nphold(1); MEM(iptr); spush = 1'b1; end
            1: begin nphold(2); TOS(data_i); iload = 1'b1; end
            default: `PHASE0;     // CC: extra memory cycle
            endcase
        put:
            case (phase)
            0: begin nphold(1); MEM(optr); dselload = 1'b1; end
            default: begin `PHASE0; POP(); dwrite(3); oload = 1'b1; end
            endcase
        default: `PHASE0;
        endcase
    end
// registers
    always_ff @(posedge clk, posedge clr) begin
        if (clr) begin
            phase <= 1'b0;
            asel  <= 1'b0;
            dsel  <= 3;
            sp    <= 0;
            sp1   <= 1;
            rp    <= 0;
            rp1   <= 1;
            iptr  <= TIB;
            optr  <= OBUF;
            t     <= {DSZ{1'b0}};
            a     <= {ASZ{1'b0}};
            p     <= {ASZ{1'b0}};
        end
        else if (clk) begin
            phase <= phase_in;
            asel  <= asel_in;

            if (cload)     code <= code_in;
            if (pload)     p    <= p_in;
            if (aload)     a    <= a_in;
            if (dselload)  dsel <= dsel_in;
            if (iload)     iptr <= iptr + 1;
            if (oload)     optr <= optr + 1;
            if (tload)     t    <= t_in;
            if      (sload) ss[sp] <= t;
            else if (spop)  begin sp <= sp - 1; sp1 <= sp1 - 1; end
            else if (spush) begin ss[sp1] <= t; sp <= sp + 1; sp1 <= sp1 + 1; end   // CC: ERROR -> EBR with multiple writers
//            else if (spush) begin ss[sp] <= t; sp <= sp + 1; sp1 <= sp1 + 1; end  // CC: use this to fix synthesizer
            if (rload)      rs[rp] <= r_in;
            else if (rpop)  begin rp <= rp - 1; rp1 <= rp1 - 1; end
            else if (rpush) begin rs[rp1] <= r_in; rp <= rp + 1; rp1 <= rp1 + 1; end
            ///
            /// validate and patch
            /// CC: do not know why DIV is skipping the branch
            ///
            if (!div_rst) div_patch();
        end
    end // always_ff @ (posedge clk, posedge clr)

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
endmodule
