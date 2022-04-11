///
/// eJsv32 Outer Interpreter Testbench
///
`timescale 1ps / 1ps
`include "../source/forthsuper_if.sv"
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
    logic [DSZ-1:0]  t_o;
    logic [ASZ-1:0]  addr_o_o, p_o, a_o;
    logic [2:0]      phase_o;
    logic [SSZ-1:0]  sp_o;
    logic [RSZ-1:0]  rp_o;
    logic            write_o;

    logic            clk, rst;
    logic [ASZ-1:0]  ctx, here;

    mb8_io      b8_if();
    spram8_128k m0(b8_if.slave, ~clk);

    dict_setup  #(MEM0, TIB) dict(.*, .b8_if(b8_if.master));
    eJ32        #(TIB, OBUF, DSZ, ASZ, SS_DEPTH, RS_DEPTH) u(.clk, .clr(rst), .*);

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
        $display("\ndump tib %04x", TIB);
        dump(TIB, 'h100);
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

    always #5 clk  = ~clk;

    assign data_o_i = b8_if.vo;

    always_comb begin
        if (write_o) b8_if.put_u8(addr_o_o, data_o_o);
        else         b8_if.get_u8(addr_o_o);
    end

    initial begin
        clk = 1'b0;           // start clock
        rst = 1'b1;           // disable eJsv32

        dict.setup_mem();     // fill dictionary from hex file
        activate();           // activate eJsv32
        repeat(100000) @(posedge clk);
        rst = 1'b1;           // disable eJsv32

        verify_tib();         // validate input buffer content
        verify_obuf();        // validate output buffer content

        #20 $finish;
    end
endmodule: outer_tb
