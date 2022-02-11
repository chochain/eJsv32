//
// eJ32 - Java Forth Machine
//
// Chen-hanson Ting, 20220110 eJsv32k.v in Quartus II SystemVerilog-2005
// Chochain          20220209 to eJ32 for Lattice and future versions
//
`include "../source/forthsuper_if.sv"
`include "../source/eJ32.vh"

`define PHASE0 phase_in = 0
`define HOLD   pload = 1'b0

module eJ32 #(
    parameter DSZ      = 32,
    parameter ASZ      = 32,
    parameter SS_DEPTH = 32,
    parameter RS_DEPTH = 32
    ) (
    input logic        clk, clr,
    input  logic[7:0]  data_o_i,
    output logic[31:0] addr_o_o, t_o, p_o, a_o,
    output logic[7:0]  data_o_o, code_o,
    output logic[2:0]  phase_o,
    output logic[4:0]  sp_o,rp_o,
    output logic       write_o);

// registers
    logic[DSZ-1:0] ss[SS_DEPTH-1:0];
    logic[DSZ-1:0] rs[RS_DEPTH-1:0];
    logic[$clog2(SS_DEPTH)-1:0] sp, sp1;
    logic[$clog2(RS_DEPTH)-1:0] rp, rp1;
    logic[DSZ-1:0] t;
    logic[ASZ-1:0] p, a;
    logic[2:0]     phase;
    logic[1:0]     dsel;
    logic          asel;
    jvm_opcode     code;
// wires
    logic[DSZ-1:0] s, r;
    logic[DSZ-1:0] t_in, r_in, t_d;
    logic[ASZ-1:0] a_in, p_in, a_d, addr_o;
    logic          tload, sload, spush, spop;  // data stack controls
    logic          rload, rpush, rpop;         // return stack controls
    logic          aload, pload;               // address controls
    logic          iload, oload;               // IO controls
    logic[7:0]     data_i, data_o;
    logic[2:0]     phase_in;
    logic[1:0]     dsel_in;
    logic          write, asel_in, dselload, cload;
    logic[DSZ-1:0] isht_o, iushr_o;
    logic          shr_f;
    logic[DSZ-1:0] iptr, optr;
    logic[DSZ-1:0] div_q, div_r;
    logic[(DSZ*2)-1:0] mul_v;
    jvm_opcode     code_in;
   
    mult  mult_inst (
    .dataa (t),
    .datab (s),
    .result (mul_v)
    );
    divide    divide_inst (
    .denom (t),
    .numer (s),
    .quotient (div_q),
    .remain (div_r)
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
    
    task nphase(input logic[2:0] n); cload = 1'b0; phase_in = (n); endtask;
    task nfetch(input logic[2:0] n); nphase(n); pload = 1'b0;      endtask;
   
    task TOA(input logic[ASZ-1:0] a);  aload = 1'b1; a_in = (a);   endtask;
    task GET(input logic[ASZ-1:0] a); TOA(a); asel_in = 1'b1;     endtask;
    task JMP(input logic[ASZ-1:0] a);  p_in = (a); aload = 1'b1;   endtask;
   
    task TOS(input logic[DSZ-1:0] v);  tload = 1'b1; t_in = (v);   endtask;
    task PUSH(input logic[DSZ-1:0] v); TOS(v); spush = 1'b1;       endtask;
    task POP();                        TOS(s); spop  = 1'b1;       endtask;
    task ALU(input logic[DSZ-1:0] v);  TOS(v); spop  = 1'b1;       endtask;
    task dwrite(input logic[2:0] n); write = 1'b1; dselload = 1'b1; dsel_in = (n); endtask;
   
    task JCMP0(input logic f);
        case (phase)
        0: begin nphase(1); TOA(data_i); end
        1: begin nphase(2); POP(); if (f) JMP(a_d); end
        default: `PHASE0;
        endcase
    endtask; // JCMP0

    task JCMPI(input logic f);
        case (phase)
        0: begin nphase(1); ALU(s - t); TOA(data_i); end
        1: begin nphase(2); POP(); if (f) JMP(a_d); end
        default: `PHASE0;
        endcase
    endtask; // JCMPI

// direct signals
    assign data_i   = data_o_i;
    assign data_o_o = data_o;
    assign addr_o_o = addr_o;
    assign write_o  = write;
    assign code_o   = code;
    assign t_o      = t;
    assign p_o      = p;
    assign a_o      = a;
    assign phase_o  = phase;
    assign sp_o     = sp;
    assign rp_o     = rp;
    assign data_o   = (dsel == 3)
                    ? t[7:0]
                    : (dsel == 2)
                        ? t[15:8]
                        : (dsel == 1)
                            ? t[23:16]
                            : t[31:24];
    assign addr_o = (asel) ? a : p;
    assign s      = ss[sp];
    assign r      = rs[rp];
    assign a_d    = {a[ASZ-9:0], data_i};     // shift combined address
    assign t_d    = {t[DSZ-9:0], data_i};     // shift combined t (top of stack)
// combinational
    always_comb begin
        a_in      = {ASZ{1'b0}};  /// address
        aload     = 1'b0;
        asel_in   = 1'b0;
        p_in      = p + 1;        /// advance program counter
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
        write     = 1'b0;
        shr_f     = 1'b0;
       
        $cast(code_in, data_i);   /// JVM opcodes, some are not avialable yet
       
        phase_in  = 0;            /// phase and IO controls
        iload     = 1'b0;
        oload     = 1'b0;
       
// instructions
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
        sipush:
            case (phase)
            0: begin nphase(1); PUSH(data_i); end
            1: begin nphase(2); TOS(t_d); end
            default: `PHASE0;
            endcase
        iload:   PUSH(rs[rp - data_i]);
        iload_0: PUSH(rs[rp]);
        iload_1: PUSH(rs[rp - 1]);
        iload_2: PUSH(rs[rp - 2]);
        iload_3: PUSH(rs[rp - 3]);
        iaload:
            case (phase)
            0: begin nfetch(1); GET(t); end
            1: begin nfetch(2); GET(a + 1); TOS(data_i); end
            2: begin nfetch(3); GET(a + 1); TOS(t_d); end
            3: begin nfetch(4); GET(a + 1); TOS(t_d); end
            4: begin nfetch(5); TOS(t_d); end
            default: `PHASE0;
            endcase
        baload:
            case (phase)
            0: begin nphase(1); GET(t); p_in = p - 1; end
            1: begin nphase(2); TOS(data_i); end
            2: begin nphase(3); /* wait 1 memory cycle */ end
            default: `PHASE0;
            endcase
        saload:
            case (phase)
            0: begin nfetch(1); GET(t); end
            1: begin nfetch(2); GET(a + 1); TOS(data_i); end
            2: begin nfetch(3); TOS(t_d); end
            default: `PHASE0;
            endcase
        istore_0: begin r_in = t; rload = 1'b1; POP(); end
        iastore:
            case (phase)
            0: begin nfetch(1); GET(s); spop = 1'b1; dselload = 1'b1; dsel_in = 0; end
            1: begin nfetch(2); GET(a + 1); dwrite(1); end
            2: begin nfetch(3); GET(a + 1); dwrite(2); end
            3: begin nfetch(4); GET(a + 1); dwrite(3); end
            4: begin nfetch(5); `HOLD; dwrite(3); POP(); end
            default: `PHASE0;
            endcase
        bastore:
            case (phase)
            0: begin nphase(1); GET(s); spop = 1'b1; p_in = p - 1; end
            1: begin nphase(2); POP(); dwrite(3); end
            default: `PHASE0; 
            endcase
        sastore:
            case (phase)
            0: begin nfetch(1); GET(s); spop = 1'b1; end
            1: begin nfetch(2); GET(a + 1); dwrite(2); end
            2: begin nfetch(3); POP(); dwrite(3); asel_in = 1'b1; end
            default: `PHASE0; 
            endcase
        pop: POP();
        pop2:
            case (phase)
            0: begin nfetch(1); POP(); end
            default: begin `PHASE0; POP(); end
            endcase
        dup: spush = 1'b1;
        dup_x1:
            case (phase)
            0: begin nfetch(1); TOA(s); end
            default: begin `PHASE0; PUSH(a); end
            endcase
        dup_x2: PUSH(ss[sp - 1]);
        dup2:
            case (phase)
            0: begin nfetch(1); TOA(s);  end
            1: begin nfetch(2); PUSH(a); end
            2: begin nfetch(3); TOA(s);  end
            default: begin `PHASE0; PUSH(a); end
            endcase
        swap: begin TOS(s); sload = 1'b1; end
        //
        // ALU ops
        //
        iadd: ALU(s + t);
        isub: ALU(s - t);
        imul: ALU(mul_v[DSZ-1:0]);
        idiv: ALU(div_q);
        irem: ALU(div_r);
        ineg: ALU(0 - t);
        ishl: ALU(isht_o);
        ishr: begin ALU(isht_o); shr_f = 1'b1; end
        iushr:ALU(iushr_o);
        iand: ALU(s & t);
        ior:  ALU(s | t);
        ixor: ALU(s ^ t);
        iinc:
            case (phase)
            0: begin phase_in = 1; GET(s); end
            1: begin phase_in = 2; `HOLD; ALU(t + data_i); asel_in = 1'b1; end
            default: begin `PHASE0; `HOLD; TOS(s); dwrite(0); end
            endcase
        //          
        // Logical ops
        //          
        ifeq:      JCMP0(t == 0);
        ifne:      JCMP0(t != 0);
        iflt:      JCMP0(t <  0);
        ifge:      JCMP0(t >= 0);
        ifgt:      JCMP0(t >  0);
        ifle:      JCMP0(t <= 0);
        if_icmpeq: JCMPI(t == 0);
        if_icmpne: JCMPI(t != 0);
        if_icmplt: JCMPI(t <  0);
        if_icmpgt: JCMPI(t >  0);
        //
        // branching
        //
        goto:
            case (phase)
            0: begin nphase(1); TOA(data_i); end
            1: begin nphase(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        jsr:
            case (phase)
            0: begin phase_in = 1; GET(t); end
            1: begin phase_in = 2; `HOLD; GET(a + 1); TOS(data_i); end
            default: begin `PHASE0; 
               p_in = t_d; PUSH(p + 2); end
            endcase
        ret: p_in = r;
        jreturn:
            case (phase)
            0: begin nphase(1); p_in = r; rpop = 1'b1; end
            default: `PHASE0;
            endcase
        invokevirtual:
            case (phase)
            0: begin nphase(1); TOA(data_i); r_in = p + 2; rpush = 1'b1; end
            1: begin nphase(2); JMP(a_d); end
            default: `PHASE0;
            endcase
        donext:
            case (phase)
            0: begin nphase(1); TOA(data_i); end
            1: begin nphase(2);
               if (r == 0) begin rpop = 1'b1; end
               else begin
                   r_in = r - 1; rload = 1'b1;
                   p_in = a_d;
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
            0: begin nfetch(1); GET(iptr); spush = 1'b1; end
            1: begin nfetch(2); TOS(data_i); iload = 1'b1; end
            default: `PHASE0; 
            endcase
        put:
            case (phase)
            0: begin nfetch(1); GET(optr); dselload = 1'b1; end
            1: begin nfetch(2); POP(); dwrite(3); oload = 1'b1; end
            default: `PHASE0; 
            endcase
        default: $display("unknown opcode %02x", data_i);
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
            iptr  <= 'h1000;
            optr  <= 'h1400;
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
            else if (spush) begin ss[sp1] <= t; sp <= sp + 1; sp1 <= sp1 + 1; end
//            else if (spush) begin ss[sp] <= t; sp <= sp + 1; sp1 <= sp1 + 1; end
            if (rload)      rs[rp] <= r_in;
            else if (rpop)  begin rp <= rp - 1; rp1 <= rp1 - 1; end
            else if (rpush) begin rs[rp1] <= r_in; rp <= rp + 1; rp1 <= rp1 + 1; end
        end
    end
endmodule
