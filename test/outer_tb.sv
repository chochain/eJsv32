///
/// eJ32 Outer Interpreter Testbench
///
`timescale 1ps / 1ps
`include "../source/eJ32_if.sv"

`define CORE ej32.core
`define CTL  ej32.ctl
`define DBUS ej32.b8_if

import ej32_pkg::*;             // import enum types

module outer_tb #(
    parameter MEM0 = 'h0,       ///> memory block addr
    parameter TIB  = 'h1000,    ///> input buffer ptr
    parameter OBUF = 'h1400     ///> output buffer ptr
    );
    //
    // return address to nfa lookup table (for tracing)
    //
    `IU ra2nfa[32];
    ///
    eJ32        ej32(.*);       ///> ej32 top module
    dict_setup  #(MEM0, TIB, OBUF) dict(.clk(~`CTL.clk), .b8_if(`DBUS.master));
    ///
    /// debugging tasks
    ///
    task dump_row(input `IU a1);
        $write("\n%04x:", a1);
        ej32.fetch(a1, 'h0);     // prefetch one memory cycle
        for (integer i=a1+1; i<=(a1+'h10); i++) begin
            if ((i % 4)==1) $write(" ");
            ej32.fetch(i, 'h1);
        end
        $write("  ");
        ej32.fetch(a1, 'h0);
        for (integer i=a1+1; i<=(a1+'h10); i++) begin
            ej32.fetch(i, 'h2);
        end
    endtask: dump_row

    task dump(input `IU a, input `IU len);
        automatic `IU a0 = a & ~'hf;
        for (integer a1=a0; a1 < (a0 + len + 'h10); a1 += 'h10) begin
            dump_row(a1);
        end
        $display("\n");
    endtask: dump

    task verify_tib;
        $display("\ndump tib: 0x%04x", TIB);
        dump(TIB, 'h200);
    endtask: verify_tib;

    task verify_dict;
        $display("\ndump dict: 0x%04x", dict.ctx);
        dump(dict.ctx, 'h80);
    endtask: verify_dict;

    task verify_obuf;
        $display("\ndump obuf: 0x%04x", OBUF);
        dump(OBUF, 'h600);
    endtask: verify_obuf

    task activate;
        `DBUS.get_u8(0);
        repeat(1) @(posedge `CTL.clk) `CTL.rst = 1'b1;
        repeat(1) @(posedge `CTL.clk) `CTL.rst = 1'b0;
    endtask: activate

    task trace;
         automatic `U5 rp  = `CORE.rp;
         automatic `U3 ph  = `CORE.phase;
         automatic opcode_t code;
         if (!$cast(code, `CTL.code)) begin
             /// JVM opcodes, some are not avialable yet
             code = op_err;
         end
         $write(
             "%6t> p:a[io]=%4x:%4x[%2x:%2x] rp=%2x<%4x> sp=%2x<%8x, %8x> %2x=%d.%-16s",
             $time/10, 
             `CORE.p,  `CORE.a, ej32.data, ej32.data_o,
             `CORE.rp, `CORE.r,
             `CORE.sp, `CORE.s, `CTL.t,
             code, `CORE.phase, code.name);
        case (`CTL.code)
        invokevirtual: if (ph==2) begin
            automatic `IU nfa = dict.to_name(ej32.addr);
            for (int i=0; i<rp; i++) $write("  ");
            $write(" :: ");
            ra2nfa[rp] = nfa;
            dict.to_s(nfa);
        end
        jreturn: if (ph==0) begin
            for (int i=0; i<rp; i++) $write("  ");
            $write(" ;; ");
            dict.to_s(ra2nfa[rp]);
        end
        endcase
        $display("");
    endtask: trace
   
    always #5 `CTL.tick();

    initial begin
        `CTL.reset();         // initialize control interface

        dict.setup();         // read ROM into memory from hex file
        verify_tib();         // validate input buffer content

        activate();           // activate eJsv32
        repeat(1000) @(posedge `CTL.clk) trace();
        
        `CTL.reset();         // disable eJsv32
        verify_dict();        // validate output dictionary words
        verify_obuf();        // validate output buffer content

        #20 $finish;
    end
endmodule: outer_tb
