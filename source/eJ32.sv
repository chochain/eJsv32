//
// eJ32 - Java Forth Machine
//
// Chen-hanson Ting, 20220110 eJsv32k.v in Quartus II SystemVerilog-2005
// Chochain          20220209 to eJ32 for Lattice and future versions
//
`include "../source/forthsuper_if.sv"
`include "../source/eJ32.vh"

`define SAMEOP   codeload = 1'b0;
`define HOLDP    codeload = 1'b1; pload = 1'b0
`define NPHASE   codeload = 1'b0; pload = 1'b0

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
    logic[DSZ-1:0] s_stack[SS_DEPTH-1:0];
    logic[DSZ-1:0] r_stack[RS_DEPTH-1:0];
    logic[$clog2(SS_DEPTH)-1:0] sp, sp1;
    logic[$clog2(RS_DEPTH)-1:0] rp, rp1;
    logic[ASZ-1:0] p, a;
    logic[DSZ-1:0] t;
    logic[2:0]     phase;
    logic[1:0]     data_sel;
    logic          addr_sel;
    jvm_opcode     code;
// wires
    logic[DSZ-1:0] s, r;
    logic[DSZ-1:0] t_in, r_in, a_in;
    logic[ASZ-1:0] p_in, addr_o;
    logic          r_z,t_z;
    logic          tload, sload, spush, spopp;
    logic          rload, rloada, rpush, rpopp, aload;
    logic[7:0]     data_i, data_o;
    logic[2:0]     phase_in;
    logic[1:0]     data_in;
    logic          write, addrload, addr_in, dataload, pload, codeload;
    logic[DSZ-1:0] isht_o, iushr_o;
    logic          shr_f;
    logic[DSZ-1:0] inptr, outptr;
    logic          inload, outload;
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
           t_in = s; tload = 1'b1; spopp = 1'b1; 
        end
        endcase
    endtask; // cond

    task cmp(f);
        case (phase)
        0: begin phase_in = 1; `SAMEOP;
            t_in = s - t; tload = 1'b1; spopp = 1'b1;
            a_in = data_i; aload = 1'b1; 
        end
        1: begin phase_in = 2; `SAMEOP;
            if (f) begin p_in = {a[23:0], data_i}; aload = 1'b1; end
        end
        default: begin phase_in = 0;
            t_in = s; tload = 1'b1; spopp = 1'b1; 
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
    assign data_o = (data_sel == 3)
                    ? t[7:0]
                    : (data_sel == 2)
                        ? t[15:8]
                        : (data_sel == 1)
                            ? t[23:16]
                            : t[31:24];
    assign addr_o = (addr_sel) ? a : p;
    assign s      = s_stack[sp];
    assign r      = r_stack[rp];
    assign t_z    = (t == 0) ? 1'b1 : 1'b0;
    assign r_z    = (r == 0) ? 1'b1 : 1'b0;
// combinational
    always_comb begin
        aload     = 1'b0;
        tload     = 1'b0;
        sload     = 1'b0;
        spush     = 1'b0;
        spopp     = 1'b0;
        rload     = 1'b0;
        rpush     = 1'b0;
        rpopp     = 1'b0;

        p_in      = p + 1;
        codeload  = 1'b1;
        pload     = 1'b1;

        addrload  = 1'b1;
        addr_in   = 1'b0;
        dataload  = 1'b0;
        data_in   = 3;
        phase_in  = 0;
        write     = 1'b0;
        t_in      = {DSZ{1'b0}};
        a_in      = {ASZ{1'b0}};
        r_in      = {DSZ{1'b0}};
        shr_f   = 1'b0;
        inload    = 1'b0;
        outload   = 1'b0;
        $cast(code_in, data_i);     // some JVM opcodes are not avialable yet
// instructions
        case (code)
        nop        : begin /* do nothing */ end
        aconst_null: begin t_in = 0;  tload = 1'b1; spush = 1'b1; end
        iconst_m1  : begin t_in = -1; tload = 1'b1; spush = 1'b1; end
        iconst_0   : begin t_in = 0;  tload = 1'b1; spush = 1'b1; end
        iconst_1   : begin t_in = 1;  tload = 1'b1; spush = 1'b1; end
        iconst_2   : begin t_in = 2;  tload = 1'b1; spush = 1'b1; end
        iconst_3   : begin t_in = 3;  tload = 1'b1; spush = 1'b1; end
        iconst_4   : begin t_in = 4;  tload = 1'b1; spush = 1'b1; end
        iconst_5   : begin t_in = 5;  tload = 1'b1; spush = 1'b1; end
        bipush:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
                    t_in = data_i; tload = 1'b1; spush = 1'b1; end
            default: begin phase_in = 0; end
            endcase
        sipush:
            case (phase)
                0: begin phase_in = 1; `SAMEOP;
                    t_in = data_i; tload = 1'b1; spush = 1'b1; end
                1: begin phase_in = 2; `SAMEOP;
                    t_in = {t[23:0], data_i}; tload = 1'b1; end
                default: begin phase_in = 0; end
            endcase
        iload:   begin t_in = r_stack[rp - data_i]; tload = 1'b1; spush = 1'b1; p_in = p + 1; end
        iload_0: begin t_in = r_stack[rp];          tload = 1'b1; spush = 1'b1; end
        iload_1: begin t_in = r_stack[rp - 1];      tload = 1'b1; spush = 1'b1; end
        iload_2: begin t_in = r_stack[rp - 2];      tload = 1'b1; spush = 1'b1; end
        iload_3: begin t_in = r_stack[rp - 3];      tload = 1'b1; spush = 1'b1; end
        iaload:
            case (phase)
            0: begin phase_in = 1; `NPHASE; 
               a_in = t; aload = 1'b1; addr_in = 1'b1; end
            1: begin phase_in = 2; `NPHASE;
               a_in = a + 1; aload = 1'b1; addr_in = 1'b1;
               t_in = data_i; tload = 1'b1; end
            2: begin phase_in = 3; `NPHASE;
               a_in = a + 1; aload = 1'b1; addr_in = 1'b1;
               t_in = {t[23:0], data_i}; tload = 1'b1; end
            3: begin phase_in = 4; `NPHASE;
               a_in = a + 1; aload = 1'b1; addr_in = 1'b1;
               t_in = {t[23:0], data_i}; tload = 1'b1; end
            4: begin phase_in = 5; `NPHASE;
               t_in = {t[23:0], data_i}; tload = 1'b1; end
            default: begin phase_in = 0; end
            endcase
        baload:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
               a_in = t; aload = 1'b1; addr_in = 1'b1;
               p_in = p - 1; end
            1: begin phase_in = 2;
               t_in = data_i; tload = 1'b1;
               code_in = nop; end
            default: begin phase_in = 0; end
            endcase
        saload:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = t; aload = 1'b1; addr_in = 1'b1; end
            1: begin phase_in = 2; `NPHASE;
               a_in = a + 1; aload = 1'b1; addr_in = 1'b1;
               t_in = data_i; tload = 1'b1; end
            2: begin phase_in = 3; `NPHASE;
               t_in = {t[23:0], data_i}; tload = 1'b1; end
            default: begin phase_in = 0; end
            endcase
        istore_0: begin
            r_in = t; rload = 1'b1;
            t_in = s; tload = 1'b1; spopp = 1'b1; end
        iastore:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = s; aload = 1'b1; addr_in = 1'b1; spopp = 1'b1;
               dataload = 1'b1; data_in = 0; end
            1: begin phase_in = 2; `NPHASE;
               a_in = a + 1  ; aload = 1'b1; addr_in = 1'b1;
               dataload = 1'b1; data_in = 1; write = 1'b1; end
            2: begin phase_in = 3; `NPHASE;
               a_in = a + 1  ; aload = 1'b1; addr_in = 1'b1;
               dataload = 1'b1; data_in = 2; write = 1'b1; end
            3: begin phase_in = 4; `NPHASE;
               a_in = a + 1  ; aload = 1'b1; addr_in = 1'b1;
               dataload = 1'b1; data_in = 3; write = 1'b1; end
            4: begin phase_in = 5; `NPHASE;
               dataload = 1'b1; data_in = 3; write = 1'b1;
               t_in = s; tload = 1'b1; spopp = 1'b1;
               p_in = p; end
            default: begin phase_in = 0; end
            endcase
        bastore:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
               a_in = s; aload = 1'b1; addr_in = 1'b1; spopp = 1'b1;
               p_in = p - 1; end
            default: begin phase_in = 0;
               t_in = s; tload = 1'b1; spopp = 1'b1;
               code_in = nop;
               dataload = 1'b1; write = 1'b1; addr_in = 1'b0; end
            endcase
        sastore:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = s; aload = 1'b1; addr_in = 1'b1; spopp = 1'b1; end
            1: begin phase_in = 2; `NPHASE;
               a_in = a + 1; aload = 1'b1; addr_in = 1'b1;
               dataload = 1'b1; data_in = 2; write = 1'b1; end
            default: begin phase_in = 0; code_in = nop; `HOLDP; 
               t_in = s; tload = 1'b1; spopp = 1'b1;
               dataload = 1'b1; write = 1'b1; addr_in = 1'b1; end
            endcase
        pop: begin t_in = s; tload = 1'b1; spopp = 1'b1; end
        pop2: begin
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               t_in = s; tload = 1'b1; spopp = 1'b1; end
            default: begin phase_in = 0;
               t_in = s; tload = 1'b1; spopp = 1'b1; end
            endcase end
        dup: begin spush = 1'b1; end
        dup_x1:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = s; aload = 1'b1; end
            default: begin phase_in = 0;
               t_in = a; spush = 1'b1; tload = 1'b1; end
            endcase
        dup_x2: begin t_in = s_stack[sp - 1]; spush = 1'b1; tload = 1'b1; end
        dup2:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
               a_in = s; aload = 1'b1; end
            1: begin phase_in = 2; `NPHASE;
               t_in = a; spush = 1'b1; tload = 1'b1; end
            2: begin phase_in = 3; `NPHASE;
               a_in = s; aload = 1'b1; end
            default: begin phase_in = 0;
               t_in = a; spush = 1'b1; tload = 1'b1; end
            endcase
        swap: begin t_in = s; tload = 1'b1; sload = 1'b1; end
        //
        // ALU ops
        //
        iadd: begin t_in = s + t;            tload = 1'b1; spopp = 1'b1; end
        isub: begin t_in = s - t;            tload = 1'b1; spopp = 1'b1; end
        imul: begin t_in = product[DSZ-1:0]; tload = 1'b1; spopp = 1'b1; end
        idiv: begin t_in = quotient;         tload = 1'b1; spopp = 1'b1; end
        irem: begin t_in = remain;           tload = 1'b1; spopp = 1'b1; end
        ineg: begin t_in = 0 - t;            tload = 1'b1; spopp = 1'b1; end
        ishl: begin t_in = isht_o;           tload = 1'b1; spopp = 1'b1; end
        ishr: begin t_in = isht_o;           tload = 1'b1; spopp = 1'b1; shr_f = 1'b1; end
        iushr:begin t_in = iushr_o;          tload = 1'b1; spopp = 1'b1; end
        iand: begin t_in = s & t;            tload = 1'b1; spopp = 1'b1; end
        ior:  begin t_in = s | t;            tload = 1'b1; spopp = 1'b1; end
        ixor: begin t_in = s ^ t;            tload = 1'b1; spopp = 1'b1; end
        iinc:
            case (phase)
            0: begin phase_in = 1;
                    a_in = s; aload = 1'b1; addrload = 1'b1; addr_in = 1'b1; end
            1: begin phase_in = 2; `HOLDP;
                    t_in = t + data_i; sload = 1'b1; addrload = 1'b1; addr_in = 1'b1;
                    spopp = 1'b1; end
            default: begin phase_in = 0; `HOLDP;
                    t_in = s; tload = 1'b1;
                    dataload = 1'b1; data_in = 0; write = 1'b1;
                    addrload = 1'b1; end
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
                    a_in = t;     aload = 1'b1; addrload = 1'b1; addr_in = 1'b1; end
            1: begin phase_in = 2; `HOLDP;
                    a_in = a + 1; aload = 1'b1; addrload = 1'b1; addr_in = 1'b1;
                    t_in = data_i; tload = 1'b1; end
            default: begin phase_in = 0;
                    p_in = {t[23:0], data_i};
                    t_in = p + 2; tload = 1'b1; spush = 1'b1; end
            endcase
        ret: begin p_in = r; end
        jreturn:
            case (phase)
            0: begin phase_in = 1; `SAMEOP;
                    p_in = r; rpopp = 1'b1; end
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
                        rpopp = 1'b1; end
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
                    t_in = data_i; tload = 1'b1; spush = 1'b1; end
            1: begin phase_in = 2; `SAMEOP;
                    t_in = {t[23:0], data_i}; tload = 1'b1; end
            2: begin phase_in = 3; `SAMEOP;
                    t_in = {t[23:0], data_i}; tload = 1'b1; end
            3: begin phase_in = 4; `SAMEOP;
                    t_in = {t[23:0], data_i}; tload = 1'b1; end
            default: begin phase_in = 0; end
            endcase
        popr: begin
            t_in = r; tload = 1'b1; spush = 1'b1; rpopp = 1'b1; end
        pushr: begin
            t_in = s; tload = 1'b1; spopp = 1'b1;
            r_in = t; rpush = 1'b1; end
        dupr: begin
            t_in = r; tload = 1'b1; spush = 1'b1; end
        get:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
                    a_in = inptr; aload = 1'b1; addr_in = 1'b1;
                    spush = 1'b1; end
            default: begin phase_in = 0; code_in = nop; `HOLDP;
                      t_in = data_i; tload = 1'b1;
                    inload = 1'b1; end
            endcase
        put:
            case (phase)
            0: begin phase_in = 1; `NPHASE;
                    a_in = outptr; aload = 1'b1; addr_in = 1'b1;
                    data_in = 3; dataload = 1'b1; end
            default: begin phase_in = 0; code_in = nop; `HOLDP;
                    t_in = s; tload = 1'b1; spopp = 1'b1;
                    data_in = 3; dataload = 1'b1; write = 1'b1;
                    outload = 1'b1; end
            endcase
        default: begin phase_in = 0; end
        endcase
    end
// registers
    always_ff @(posedge clk, posedge clr) begin
        if (clr) begin
            phase <= 1'b0;
            addr_sel <= 1'b0;
            data_sel <= 3;
            sp  <= 0;
            sp1 <= 1;
            rp  <= 0;
            rp1 <= 1;
            inptr  <= 'h1000;
            outptr <= 'h1400;
            t   <= {DSZ{1'b0}};
            a   <= {ASZ{1'b0}};
            p   <= {ASZ{1'b0}};
            end
        else if (clk) begin
            phase <= phase_in;
            if (codeload)  code <= code_in;
            if (pload)     p <= p_in;
            if (aload)     a <= a_in;
            if (addrload)  addr_sel <= addr_in;
            if (dataload)  data_sel <= data_in;
            if (inload)    inptr <= inptr + 1;
            if (outload)   outptr <= outptr + 1;
            if (tload)     t <= t_in;
            if (sload)     s_stack[sp] <= t;
            if (rload)     r_stack[rp] <= r_in;
            if (spopp)     begin sp <= sp - 1; sp1 <= sp1 - 1; end
            if (rpopp)     begin rp <= rp - 1; rp1 <= rp1 - 1; end
            if (spush)     begin
//              s_stack[sp1] <= t;
                s_stack[sp] <= t;
                sp <= sp + 1; sp1 <= sp1 + 1; end
            if (rpush)     begin
                r_stack[rp1] <= r_in;
                rp <= rp + 1; rp1 <= rp1 + 1; end
        end
    end
endmodule
