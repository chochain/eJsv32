///
/// eJ32 Outer Interpreter Testbench
///
`timescale 1ps / 1ps
`include "../source/eJ32_if.sv"
`include "../source/eJ32.vh"
module outer_tb #(
    parameter MEM0 = 'h0,       /* memory block addr  */
    parameter TIB  = 'h1000,    /* input buffer ptr   */
    parameter OBUF = 'h1400,    /* output buffer ptr  */
    parameter DSZ  = 32,        /* 32-bit data width  */
    parameter ASZ  = 17,        /* 128K address space */
    parameter SS_DEPTH = 32,
    parameter RS_DEPTH = 32
    );
    localparam SSZ = $clog2(SS_DEPTH);
    localparam RSZ = $clog2(RS_DEPTH);
    localparam DOT = 'h2e;

    `U8 code_o;
    `DU t_o, s_o, r_o;
    `IU addr_o, p_o, a_o;
    `U8 data_i, data_o;
    `U3 phase_o;
    `U5 sp_o;
    `U5 rp_o;
    `U1 dwe_o;

    `U1 clk, rst;
    `IU ctx, here;
    //
    // return address to nfa (for tracing)
    //
    `IU ra2nfa[RS_DEPTH];

    mb8_io      b8_if();
    spram8_128k m0(b8_if.slave, ~clk);

    dict_setup  #(MEM0, TIB, OBUF) dict(.*, .b8_if(b8_if.master));
    eJ32        #(TIB, OBUF, DSZ, ASZ, SS_DEPTH, RS_DEPTH) ej32(.clk, .rst, .*);


    task at(`IU ax, `U2 opt);
        repeat(1) @(posedge clk) begin
            case (opt)
            'h1: $write("%02x", b8_if.vo);
            'h2: $write("%c", b8_if.vo < 'h20 ? DOT : b8_if.vo);
            endcase
            b8_if.get_u8(ax);
        end
    endtask: at

    task dump_row(`IU a1);
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

    task dump(input `IU addr, input `IU len);
        automatic `IU a0 = addr & ~'hf;
        for (integer a1=a0; a1 < (a0 + len + 'h10); a1 += 'h10) begin
            dump_row(a1);
        end
        $display("\n");
    endtask: dump

    task verify_tib;
        $display("\ndump tib: 0x%04x", TIB);
        dump(TIB, 'h120);
    endtask: verify_tib;

    task verify_dict;
        $display("\ndump dict: 0x%04x", dict.ctx);
        dump(dict.ctx, 'h80);
    endtask: verify_dict;

    task verify_obuf;
        $display("\ndump obuf: 0x%04x", OBUF);
        dump(OBUF, 'h80);
    endtask: verify_obuf

    task activate;
        b8_if.get_u8(0);
        repeat(1) @(posedge clk) rst = 1;
        repeat(1) @(posedge clk) rst = 0;
    endtask: activate

    task trace;
        automatic opcode_t code;
        if (!$cast(code, code_o)) begin
            /// JVM opcodes, some are not avialable yet
            code = op_err;
        end
        $write(
            "%6t> p:a[io]=%4x:%4x[%2x:%2x] rp=%2x<%4x> sp=%2x<%8x, %8x> %2x=%d.%-16s",
            $time/10, p_o, a_o, data_i, data_o, rp_o, ej32.rs[rp_o], sp_o, s_o, t_o, code_o, phase_o, code.name);
        if (code==invokevirtual && phase_o==2) begin
            automatic `IU nfa = dict.to_name(addr_o);
            for (int i=0; i<rp_o; i++) $write("  ");
            $write(" :: ");
            ra2nfa[rp_o] = nfa;
            dict.to_s(nfa);
        end
        else if (code==jreturn && phase_o==0) begin
            for (int i=0; i<rp_o; i++) $write("  ");
            $write(" ;; ");
            dict.to_s(ra2nfa[rp_o]);
        end
        $display("");
    endtask: trace

    always #5 clk  = ~clk;

    assign data_i = b8_if.vo;

    always_comb begin
        if (dwe_o) b8_if.put_u8(addr_o, data_o);
        else       b8_if.get_u8(addr_o);
    end

    initial begin
        clk = 1'b0;           // start clock
        rst = 1'b1;           // disable eJsv32

        dict.setup();         // read ROM into memory from hex file
        verify_tib();         // validate input buffer content

        activate();           // activate eJsv32
        repeat(1000) @(posedge clk) trace();
        rst = 1'b1;           // disable eJsv32

        verify_dict();        // validate output dictionary words
        verify_obuf();        // validate output buffer content

        #20 $finish;
    end
endmodule: outer_tb
