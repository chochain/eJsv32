///
/// eJ32 Outer Interpreter Testbench
///
`timescale 1ps / 1ps
`include "../source/eJ32_if.sv"

`define DBUS ej32.b8_if
`define CTL  ej32.ctl
`define AU   ej32.au
`define BR   ej32.br
`define LS   ej32.ls

import ej32_pkg::*;             // import enum types

module outer_tb #(
    parameter MEM0 = 'h0,       ///> memory block addr
    parameter ROM_SZ   = 8192,  ///> ROM hosted eForth image size in bytes
    parameter ROM_WAIT = 3      ///> wait cycle to stablize ROM read
    );
    localparam P2N_SZ = 200;
    ///
    EJ32 ej32(.*);              ///> ej32 top module
    ///
    /// dictionary tracer
    ///
    `U1 clk, rst;               ///> clock driver
    `IU cold, ctx, tib, obuf;   ///> eForth user variables
   
    typedef struct {
        `IU nfa;                ///> name field address
        `IU pfa;                ///> parameter field address
    } t_p2n;
    `U8   ram[ROM_SZ];          ///> fake initial ROM
    `U8   p2n_sz;               ///> size of lookup table
    t_p2n p2n[P2N_SZ];          ///> lookup table
   
    task build_p2n(input `IU ctx);
        automatic `IU a = ctx;
        automatic integer i;
        for (i=0; a && i<P2N_SZ; i++) begin
            automatic `U8 len = ram[a] & 'h1f;
            $display("nfa=%x, pfa=%x", a, a + len + 1);
            p2n[i].nfa = a;
            p2n[i].pfa = a + len + 'h1;
            a = {ram[a-2], ram[a-1]};
        end
        p2n_sz = i;
    endtask: build_p2n

    function `IU to_name(`IU pfa);
        automatic `IU a = 'h0;
        for (int i=0; i<p2n_sz && a=='h0; i++) begin
            if (p2n[i].pfa == pfa) a = p2n[i].nfa;
        end
        to_name = a;
    endfunction: to_name

    task to_s(`IU nfa);
        automatic `U8 len = ram[nfa] & 'h1f;
        for (int i=1; i<=len; i++) begin
            $write("%c", ram[nfa+i]);
        end
    endtask: to_s

    task words;
        for (int i=0; i<p2n_sz; i++) begin
            automatic `IU a = p2n[i].nfa;
            $write("%c%4x: ", ram[a] & 'h80 ? "*" : " ", a + (ram[a] & 'h1f) + 'h1);
            to_s(a);
            $display("");
        end
    endtask: words
    ///
    /// memory dummper
    ///
    localparam DOT = 'h2e;      ///> '.'
    task peek(input `IU ax, input `U2 opt);
        automatic `U8 data = ram[ax];          // 1 cycle delay
        case (opt)
        'h1: $write("%02x", data);
        'h2: $write("%c", data < 'h20 ? DOT : data);
        endcase
    endtask: peek
   
    task dump_row(input `IU a1);
        $write("\n%04x:", a1);
        peek(a1, 'h0);     // prefetch one memory cycle
        for (integer i=a1; i< (a1 + 'h10); i++) begin
            if ((i % 4)==0) $write(" ");
            peek(i, 'h1);
        end
        $write("  ");
        peek(a1, 'h0);
        for (integer i=a1; i< (a1 + 'h10); i++) begin
            peek(i, 'h2);
        end
    endtask: dump_row

    task dump(input string s, input `IU a, input `IU len);
        automatic `IU a0 = a & ~'hf;
        $display("\dump %s: 0x%04x", s, a);
        for (integer a1=a0; a1 < (a0 + len + 'h10); a1 += 'h10) begin
            dump_row(a1);
        end
        $display("\n");
    endtask: dump
    ///
    /// debugging
    ///
    task ram_copy(input `IU ax, input `IU len);
        automatic `IU a0 = ax & ~'hf;
        for (integer a1=a0; a1 <= (a0 + len + 'h10); a1++) begin
            repeat(1) @(posedge clk) begin
                `DBUS.get_u8(a1);
                if (a1 > a0) ram[a1-1] = `DBUS.vo; ///> 1-cycle delay
            end
        end
    endtask: ram_copy
    ///
    /// eJ32 execution tracer
    ///
    `IU ra2nfa[32];                   ///> return address to nfa lookup table
   
    task pre_check();
        cold = { ram['h01], ram['h02] };   // cold start address
        ctx  = { ram['h50], ram['h51] };   // eForth current context
        tib  = { ram['h6e], ram['h6f] };   // eForth terminal input buffer 
        obuf = { ram['h72], ram['h73] };   // eForth output buffer 

        dump("user", 0,  'h120);           // verify eForth variables, and
        dump("dict", ctx-'h100, 'h120);    // primitive words
        dump("tib",  tib,'h120);           // verify input buffer content
        build_p2n(ctx);                    // construct pfa=>nfa lookup table
        words();                           // walk word list
       
        $display("eForth cold starting at: %x", cold);
    endtask: pre_check

    task post_check();
        ram_copy(ctx, 'h120);        // post copy RAM content for verification
        dump("dict", ctx, 'h120);
        ram_copy(obuf, 'h600);
        dump("obuf", obuf,'h600);    // verify output buffer content
    endtask: post_check
   
    task trace;
        automatic `U3 ph = `CTL.phase;
        automatic `SU rp = `BR.rp;
        automatic `U8 d8 = `DBUS.vo; // `DBUS.we ? `DBUS.vi : `DBUS.vo;
        automatic `U8 xx;
        automatic opcode_t code;
        if (!$cast(code, `CTL.code)) begin
             /// JVM opcodes, some are not avialable yet
             code = op_err;
        end
        $write(
             "%6t> p:a[io]=%4x:%4x[%2x:%2x] rp=%2x<%4x> sp=%2x<%8x, %8x> %2x=%d%s%-16s",
             $time/10, 
             ej32.p, `LS.a,
             `BR.asel ? xx : d8, `BR.asel ? d8 : xx,
             `BR.rp, `BR.r,
             `AU.sp, `AU.s, `AU.t,
             code, ph, ej32.div_bsy_o ? "." : "_", code.name);
        case (code)
        invokevirtual: if (ph==2) begin
            automatic `IU nfa = to_name(ej32.p);
            for (int i=0; i<rp; i++) $write("  ");
            $write(" :: ");
            ra2nfa[rp] = nfa;
            to_s(nfa);
        end
        jreturn: if (ph==0) begin
            for (int i=0; i<rp; i++) $write("  ");
            $write(" ;; ");
            to_s(ra2nfa[rp]);
        end
        endcase
        $display("");
    endtask: trace
    ///
    /// eJ32 activation
    ///
    task activate;
        `DBUS.get_u8(0);
        repeat(1) @(posedge clk) rst = 1'b1;
        repeat(1) @(posedge clk) rst = 1'b0;
    endtask: activate

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        `CTL.reset();                  // initialize control interface
        ///
        /// load ROM and TIB into RAM
        ///
        activate();                    // activate eJsv32
        repeat(ROM_SZ) @(posedge clk) begin
            ram[`DBUS.ai] = `DBUS.vi;  // capture a local copy
            if (`DBUS.ai < 'h10) begin
               $display("%4x:%2x ", `DBUS.ai, `DBUS.vi);
            end
        end
        ///
        /// validate TIB and dictionary
        ///
        pre_check();
        ///
        /// simulate eJ32
        ///
        repeat(23000) @(posedge clk) trace();
        ///
        /// verify user words and output buffer
        ///
        rst = 1'b1;
        `CTL.reset();
        post_check();

        #20 $finish;
    end
endmodule: outer_tb
