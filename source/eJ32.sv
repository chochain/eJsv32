//
// eJ32 - Java Forth Machine
//
// Chen-hanson Ting, 20220110 eJsv32k.v in Quartus II SystemVerilog-2005
// Chochain          20220209 to eJ32 for Lattice and future versions
//
`include "../source/forthsuper_if.sv"
`include "../source/eJ32.vh"

`define SAMEOP   cload = 1'b0;
`define HOLDP    cload = 1'b1; pload = 1'b0
`define NPHASE   cload = 1'b0; pload = 1'b0
`define NEWADR   aload = 1'b1; asel_in = 1'b1
`define TOS(v)   tload = 1'b1; t_in = v
`define PUSH     tload = 1'b1; spush = 1'b1
`define POP      tload = 1'b1; spop  = 1'b1

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
    logic[ASZ-1:0] p, a;
    logic[DSZ-1:0] t;
    logic[2:0]     phase;
    logic[1:0]     dsel;
    logic          asel;
    jvm_opcode     code;
// wires
    logic[DSZ-1:0] s, r;
    logic[DSZ-1:0] t_in, r_in, a_in;
    logic[ASZ-1:0] p_in, addr_o;
    logic          r_z,t_z;
    logic          tload, sload, spush, spop;
    logic          rload, rloada, rpush, rpop, aload;
    logic[7:0]     data_i, data_o;
    logic[2:0]     phase_in;
    logic[1:0]     dsel_in;
    logic          write, aselload, asel_in, dselload, pload, cload;
    logic[DSZ-1:0] isht_o, iushr_o;
    logic          shr_f;
    logic[DSZ-1:0] iptr, optr;
    logic          iload, oload;
    logic[DSZ-1:0] quotient, remain;
    logic[(DSZ*2)-1:0] product;
    jvm_opcode     code_in;
   
    mult  mult_inst (
    .dataa (t),
    .datab (s),
    .result (product)
    );
    divide    divide_inst (
    .denom (t),
    .numer (s),
    .quotient (quotient),
    .remain (remain)
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

    task cond(f);
        case (phase)
        0: begin phase_in = 1; `SAMEOP;
           a_in = data_i; aload = 1'b1; 
        end
        1: begin phase_in = 2; `SAMEOP;
           if (f) begin p_in = {a[23:0], data_i}; aload = 1'b1; end
        end
        default: begin phase_in = 0;
           t_in = s; `POP; 
        end
        endcase
    endtask; // cond

    task cmp(f);
        case (phase)
        0: begin phase_in = 1; `SAMEOP;
            t_in = s - t; `POP;
            a_in = data_i; aload = 1'b1; 
        end
        1: begin phase_in = 2; `SAMEOP;
            if (f) begin p_in = {a[23:0], data_i}; aload = 1'b1; end
        end
        default: begin phase_in = 0;
            t_in = s; `POP; 
        end
        endcase
    endtask; // cmp

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
    assign t_z    = (t == 0) ? 1'b1 : 1'b0;
    assign r_z    = (r == 0) ? 1'b1 : 1'b0;
// combinational
    always_comb begin
        // address
        a_in      = {ASZ{1'b0}};
        aload     = 1'b0;
        asel_in   = 1'b0;
        aselload  = 1'b1;
        // program counter       
        p_in      = p + 1;
        pload     = 1'b1;
        cload     = 1'b1;
        // TOS
        t_in      = {DSZ{1'b0}};
        tload     = 1'b0;
        // data stack
        sload     = 1'b0;
        spush     = 1'b0;
        spop      = 1'b0;
        // return stack       
        r_in      = {DSZ{1'b0}};
        rload     = 1'b0;
        rpush     = 1'b0;
        rpop      = 1'b0;
        // data
        dselload  = 1'b0;
        dsel_in   = 3;
        write     = 1'b0;
        shr_f     = 1'b0;
        $cast(code_in, data_i);     // some JVM opcodes are not avialable yet
        // phase and io control
        phase_in  = 0;
        iload     = 1'b0;
        oload     = 1'b0;
       
// instructions
        case (code)
        nop        : begin /* do nothing */ end
        aconst_null: begin t_in = 0;  `PUSH; end
        iconst_m1  : begin t_in = -1; `PUSH; end
        iconst_0   : begin t_in = 0;  `PUSH; end
        iconst_1   : begin t_in = 1;  `PUSH; end
        iconst_2   : begin t_in = 2;  `PUSH; end
        iconst_3   : begin t_in = 3;  `PUSH; end
        iconst_4   : begin t_in = 4;  `PUSH; end
        iconst_5   : begin t_in = 5;  `PUSH; end
        bipush:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
                    t_in = data_i; `PUSH; end
            default: begin phase_in = 0; end
            endcase
        sipush:
            case (phase)
                0: begin phase_in = 1; `SAMEOP;
                    t_in = data_i; `PUSH; end
                1: begin phase_in = 2; `SAMEOP;
                    `TOS({t[23:0], data_i}); end
                default: begin phase_in = 0; end
            endcase
        iload:   begin t_in = rs[rp - data_i]; `PUSH; p_in = p + 1; end
        iload_0: begin t_in = rs[rp];          `PUSH; end
        iload_1: begin t_in = rs[rp - 1];      `PUSH; end
        iload_2: begin t_in = rs[rp - 2];      `PUSH; end
        iload_3: begin t_in = rs[rp - 3];      `PUSH; end
        iaload:
            case (phase)
            0: begin phase_in = 1; `NPHASE; 
               a_in = t; `NEWADR; end
            1: begin phase_in = 2; `NPHASE;
               a_in = a + 1; `NEWADR; `TOS(data_i); end
            2: begin phase_in = 3; `NPHASE;
               a_in = a + 1; `NEWADR; `TOS({t[23:0], data_i}); end
            3: begin phase_in = 4; `NPHASE;
               a_in = a + 1; `NEWADR; `TOS({t[23:0], data_i}); end
            4: begin phase_in = 5; `NPHASE; `TOS({t[23:0], data_i}); end
            default: begin phase_in = 0; end
            endcase
        baload:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
               a_in = t; `NEWADR;
               p_in = p - 1; end
            1: begin phase_in = 2;
               `TOS(data_i); code_in = nop; end
            default: begin phase_in = 0; end
            endcase
        saload:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = t; `NEWADR; end
            1: begin phase_in = 2; `NPHASE;
               a_in = a + 1; `NEWADR; `TOS(data_i); end
            2: begin phase_in = 3; `NPHASE; `TOS({t[23:0], data_i}); end
            default: begin phase_in = 0; end
            endcase
        istore_0: begin
            r_in = t; rload = 1'b1;
            t_in = s; `POP; end
        iastore:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = s; `NEWADR; spop = 1'b1;
               dselload = 1'b1; dsel_in = 0; end
            1: begin phase_in = 2; `NPHASE;
               a_in = a + 1  ; `NEWADR;
               dselload = 1'b1; dsel_in = 1; write = 1'b1; end
            2: begin phase_in = 3; `NPHASE;
               a_in = a + 1  ; `NEWADR;
               dselload = 1'b1; dsel_in = 2; write = 1'b1; end
            3: begin phase_in = 4; `NPHASE;
               a_in = a + 1  ; `NEWADR;
               dselload = 1'b1; dsel_in = 3; write = 1'b1; end
            4: begin phase_in = 5; `NPHASE;
               dselload = 1'b1; dsel_in = 3; write = 1'b1;
               t_in = s; `POP;
               p_in = p; end
            default: begin phase_in = 0; end
            endcase
        bastore:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
               a_in = s; `NEWADR; spop = 1'b1;
               p_in = p - 1; end
            default: begin phase_in = 0;
               t_in = s; `POP;
               code_in = nop;
               dselload = 1'b1; write = 1'b1; asel_in = 1'b0; end
            endcase
        sastore:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = s; `NEWADR; spop = 1'b1; end
            1: begin phase_in = 2; `NPHASE;
               a_in = a + 1; `NEWADR;
               dselload = 1'b1; dsel_in = 2; write = 1'b1; end
            default: begin phase_in = 0; code_in = nop; `HOLDP; 
               t_in = s; `POP;
               dselload = 1'b1; write = 1'b1; asel_in = 1'b1; end
            endcase
        pop: begin t_in = s; `POP; end
        pop2: begin
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               t_in = s; `POP; end
            default: begin phase_in = 0;
               t_in = s; `POP; end
            endcase end
        dup: begin spush = 1'b1; end
        dup_x1:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = s; aload = 1'b1; end
            default: begin phase_in = 0;
               t_in = a; `PUSH; end
            endcase
        dup_x2: begin t_in = ss[sp - 1]; `PUSH; end
        dup2:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = s; aload = 1'b1; end
            1: begin phase_in = 2; `NPHASE;
               t_in = a; `PUSH; end
            2: begin phase_in = 3; `NPHASE;
               a_in = s; aload = 1'b1; end
            default: begin phase_in = 0;
               t_in = a; `PUSH; end
            endcase
        swap: begin `TOS(s); sload = 1'b1; end
        //
        // ALU ops
        //
        iadd: begin t_in = s + t;            `POP; end
        isub: begin t_in = s - t;            `POP; end
        imul: begin t_in = product[DSZ-1:0]; `POP; end
        idiv: begin t_in = quotient;         `POP; end
        irem: begin t_in = remain;           `POP; end
        ineg: begin t_in = 0 - t;            `POP; end
        ishl: begin t_in = isht_o;           `POP; end
        ishr: begin t_in = isht_o;           `POP; shr_f = 1'b1; end
        iushr:begin t_in = iushr_o;          `POP; end
        iand: begin t_in = s & t;            `POP; end
        ior:  begin t_in = s | t;            `POP; end
        ixor: begin t_in = s ^ t;            `POP; end
        iinc:
            case (phase)
            0: begin phase_in = 1;
                    a_in = s; `NEWADR; aselload = 1'b1; end
            1: begin phase_in = 2; `HOLDP;
                    t_in = t + data_i; sload = 1'b1; aselload = 1'b1; asel_in = 1'b1;
                    spop = 1'b1; end
            default: begin phase_in = 0; `HOLDP; `TOS(s);
                    dselload = 1'b1; dsel_in = 0; write = 1'b1;
                    aselload = 1'b1; end
            endcase
        //          
        // Logical ops
        //          
        ifeq:      cond(t_z);
        ifne:      cond(t_z == 1'b0);
        iflt:      cond(t[31]);
        ifge:      cond(t[31] == 1'b0);
        ifgt:      cond((t[31]==1'b0) && (t_z==1'b0));
        ifle:      cond((t[31]==1'b1) || (t_z==1'b1));
        if_icmpeq: cmp(t_z);
        if_icmpne: cmp(t_z == 1'b0);
        if_icmplt: cmp(t[31]);
        if_icmpgt: cmp((t[31]==1'b0) && (t_z==1'b0));
        //
        // branching
        //
        goto:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
                    a_in = data_i; aload = 1'b1; end
            1: begin phase_in = 2; `SAMEOP;
                    p_in = {a[23:0], data_i}; end
            default: begin phase_in = 0; end
            endcase
        jsr:
            case (phase)
            0: begin phase_in = 1;
                    a_in = t;     `NEWADR; aselload = 1'b1; end
            1: begin phase_in = 2; `HOLDP;
                    a_in = a + 1; `NEWADR; aselload = 1'b1; 
                    `TOS(data_i); end
            default: begin phase_in = 0;
                    p_in = {t[23:0], data_i};
                    t_in = p + 2; `PUSH; end
            endcase
        ret: begin p_in = r; end
        jreturn:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
                    p_in = r; rpop = 1'b1; end
            default: begin phase_in = 0; end
            endcase
        invokevirtual:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
                    r_in = p + 2; rpush = 1'b1;
                    a_in = data_i; aload = 1'b1; end
            1: begin phase_in = 2; `SAMEOP;
                    p_in = {a[23:0], data_i}; aload = 1'b1; end
            default: begin phase_in = 0; end
            endcase
        donext:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
                    a_in = data_i; aload = 1'b1; end
            1: begin phase_in = 2; `SAMEOP;
                    if (r_z) begin
                        rpop = 1'b1; end
                    else begin
                        r_in = r - 1; rload = 1'b1;
                        p_in = {a[23:0], data_i};
                    end
                    end
            default: begin phase_in = 0; end
            endcase
        ldi:
            case (phase)
            0: begin phase_in =1; `SAMEOP;
                    t_in = data_i; `PUSH; end
            1: begin phase_in = 2; `SAMEOP; `TOS({t[23:0], data_i}); end
            2: begin phase_in = 3; `SAMEOP; `TOS({t[23:0], data_i}); end
            3: begin phase_in = 4; `SAMEOP; `TOS({t[23:0], data_i}); end
            default: begin phase_in = 0; end
            endcase
        popr: begin
            t_in = r; `PUSH; rpop = 1'b1; end
        pushr: begin
            t_in = s; `POP;
            r_in = t; rpush = 1'b1; end
        dupr: begin
            t_in = r; `PUSH; end
        get:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
                    a_in = iptr; `NEWADR;
                    spush = 1'b1; end
            default: begin phase_in = 0; 
                    code_in = nop; `HOLDP;
                    `TOS(data_i); iload = 1'b1; end
            endcase
        put:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
                    a_in = optr; `NEWADR;
                    dsel_in = 3; dselload = 1'b1; end
            default: begin phase_in = 0; code_in = nop; `HOLDP;
                    t_in = s; `POP;
                    dsel_in = 3; dselload = 1'b1; write = 1'b1;
                    oload = 1'b1; end
            endcase
        default: begin phase_in = 0; end
        endcase
    end
// registers
    always_ff @(posedge clk, posedge clr) begin
        if (clr) begin
            phase <= 1'b0;
            asel <= 1'b0;
            dsel <= 3;
            sp  <= 0;
            sp1 <= 1;
            rp  <= 0;
            rp1 <= 1;
            iptr  <= 'h1000;
            optr <= 'h1400;
            t   <= {DSZ{1'b0}};
            a   <= {ASZ{1'b0}};
            p   <= {ASZ{1'b0}};
            end
        else if (clk) begin
            phase <= phase_in;
            if (cload)     code <= code_in;
            if (pload)     p <= p_in;
            if (aload)     a <= a_in;
            if (aselload)  asel <= asel_in;
            if (dselload)  dsel <= dsel_in;
            if (iload)     iptr <= iptr + 1;
            if (oload)     optr <= optr + 1;
            if (tload)     t <= t_in;
            if (sload)     ss[sp] <= t;
            if (rload)     rs[rp] <= r_in;
            if (spop)      begin sp <= sp - 1; sp1 <= sp1 - 1; end
            if (rpop)      begin rp <= rp - 1; rp1 <= rp1 - 1; end
            if (spush)     begin
                ss[sp1] <= t;
//                ss[sp] <= t;
                sp <= sp + 1; sp1 <= sp1 + 1; end
            if (rpush)     begin
                rs[rp1] <= r_in;
                rp <= rp + 1; rp1 <= rp1 + 1; end
        end
    end
endmodule
