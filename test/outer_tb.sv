///
/// eJsv32 Outer Interpreter Testbench
///
`timescale 1ps / 1ps
`include "../source/forthsuper_if.sv"
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

    logic [7:0]      data_o_i, data_o_o, code_o;
    logic [DSZ-1:0]  s_o, t_o;
    logic [ASZ-1:0]  addr_o_o, p_o, a_o;
    logic [2:0]      phase_o;
    logic [SSZ-1:0]  sp_o;
    logic [RSZ-1:0]  rp_o;
    logic            write_o;

    logic            clk, rst;
    logic [ASZ-1:0]  ctx, here;
    logic [ASZ-1:0]  ra2nfa[RS_DEPTH-1:0];     /// return address to nfa (for tracing)

    mb8_io      b8_if();
    spram8_128k m0(b8_if.slave, ~clk);

    dict_setup  #(MEM0, TIB, OBUF) dict(.*, .b8_if(b8_if.master));
    eJ32        #(TIB, OBUF, DSZ, ASZ, SS_DEPTH, RS_DEPTH) ej32(.clk, .clr(rst), .*);


    task at([ASZ-1:0] ax, [1:0] opt);
        repeat(1) @(posedge clk) begin
            case (opt)
            'h1: $write("%02x", b8_if.vo);
            'h2: $write("%c", b8_if.vo < 'h20 ? DOT : b8_if.vo);
            endcase
            b8_if.get_u8(ax);
        end
    endtask: at

    task dump_row(input [ASZ-1:0] a1);
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

    task dump(input [ASZ-1:0] addr, input [ASZ-1:0] len);
        automatic logic [ASZ-1:0] a0 = addr & ~'hf;
        for (integer a1=a0; a1 < (a0 + len + 'h10); a1 += 'h10) begin
            dump_row(a1);
        end
    endtask: dump

    task verify_tib;
        $display("\ndump mem %04x", TIB);
        dump(TIB, 'h120);
    endtask: verify_tib;

    task verify_obuf;
        $display("\ndump obuf %04x", OBUF);
        dump(OBUF, 'h400);
    endtask: verify_obuf

    task activate;
        b8_if.get_u8(0);
        repeat(1) @(posedge clk) rst = 1;
        repeat(1) @(posedge clk) rst = 0;
    endtask: activate

    task trace;
        automatic jvm_opcode code;
        if (!$cast(code, code_o)) begin
            /// JVM opcodes, some are not avialable yet
            code = op_err;
        end
        $write(
            "%6t> p:a[io]=%4x:%4x[%2x:%2x] rp=%2x<%4x> sp=%2x<%8x, %8x> %2x=%d.%-16s",
            $time, p_o, a_o, data_o_i, data_o_o, rp_o, ej32.rs[rp_o], sp_o, s_o, t_o, code_o, phase_o, code.name);
        if (code==invokevirtual && phase_o==2) begin
            automatic logic[ASZ-1:0] nfa = dict.to_name(addr_o_o);
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

    assign data_o_i = b8_if.vo;

    always_comb begin
        if (write_o) b8_if.put_u8(addr_o_o, data_o_o);
        else         b8_if.get_u8(addr_o_o);
    end

    initial begin
        clk = 1'b0;           // start clock
        rst = 1'b1;           // disable eJsv32

        dict.setup();         // read ROM into memory from hex file

        activate();           // activate eJsv32
        repeat(120000) @(posedge clk) trace();
        rst = 1'b1;           // disable eJsv32

        verify_tib();         // validate input buffer content
        verify_obuf();        // validate output buffer content

        #20 $finish;
    end
endmodule: outer_tb
