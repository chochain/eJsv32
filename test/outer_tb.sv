///
/// eJ32 Outer Interpreter Testbench
///
`timescale 1ps / 1ps
`include "../source/eJ32.vh"
`include "../source/eJ32_if.sv"

import ej32_pkg::*;             // import enum types

module outer_tb #(
    parameter MEM0 = 'h0,       // memory block addr
    parameter TIB  = 'h1000,    // input buffer ptr
    parameter OBUF = 'h1400     // output buffer ptr
    );
    localparam DOT = 'h2e;
    // dict module
    `IU  ctx, here;
    // ej32 module
    `IU  addr_t;
    `U3  phase_t;
    `U5  rp_t;
    //
    // return address to nfa (for tracing)
    //
    `IU ra2nfa[32];

    ej32_ctl    ctl();
    mb8_io      b8_if();
    dict_setup  #(MEM0, TIB, OBUF) dict(.clk(~ctl.clk), .b8_if(b8_if.master), .*);
    top         top_inst(.*);

    task at(input `IU ax, input `U2 opt);
        repeat(1) @(posedge ctl.clk) begin
            case (opt)
            'h1: $write("%02x", b8_if.vo);
            'h2: $write("%c", b8_if.vo < 'h20 ? DOT : b8_if.vo);
            endcase
            b8_if.get_u8(ax);
        end
    endtask: at

    task dump_row(input `IU a1);
        $write("\n%04x:", a1);
        at(a1, 'h0);                     // prefetch one memory cycle
        for (integer i=a1+1; i<=(a1+'h10); i++) begin
            if ((i % 4)==1) $write(" ");
            at(i, 'h1);
        end
        $write("  ");
        at(a1, 'h0);
        for (integer i=a1+1; i<=(a1+'h10); i++) begin
            at(i, 'h2);
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
        b8_if.get_u8(0);
        repeat(1) @(posedge ctl.clk) ctl.rst = 1'b1;
        repeat(1) @(posedge ctl.clk) ctl.rst = 1'b0;
    endtask: activate

    task show_callstack;
        case (ctl.code)
        invokevirtual: if (phase_t==2) begin
            automatic `IU nfa = dict.to_name(addr_t);
            for (int i=0; i<rp_t; i++) $write("  ");
            $write(" :: ");
            ra2nfa[rp_t] = nfa;
            dict.to_s(nfa);
        end
        jreturn: if (phase_t==0) begin
            for (int i=0; i<rp_t; i++) $write("  ");
            $write(" ;; ");
            dict.to_s(ra2nfa[rp_t]);
        end
        endcase
        $display("");
    endtask: show_callstack
   
    always #5 ctl.tick();

    initial begin
        ctl.clk = 1'b1;       // memory fetch on negative edge
        ctl.rst = 1'b1;
        ctl.t   = 0;

        dict.setup();         // read ROM into memory from hex file
        verify_tib();         // validate input buffer content

        activate();           // activate eJsv32
        repeat(1000) @(posedge ctl.clk) begin
           top_inst.trace();
           show_callstack();
        end
        ctl.rst = 1'b1;       // disable eJsv32

        verify_dict();        // validate output dictionary words
        verify_obuf();        // validate output buffer content

        #20 $finish;
    end
endmodule: outer_tb
