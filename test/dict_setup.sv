///
/// eJ32 Dictionary Setup Testbench
///
`include "../source/eJ32_if.sv"

module dict_setup #(
    parameter MEM0 = 'h0,       /// starting address of memory block
    parameter TIB  = 'h1000,    /// terminal input buffer
    parameter OBUF = 'h1400,    /// terminal output buffer
    parameter DSZ  = 8,         /// 8-bit data path
    parameter ASZ  = 17         /// 128K address space
    ) (
    mb8_io b8_if,               /// 8-bit memory bus master
    input  clk,
    output `IU ctx,              /// context
    output `IU here              /// starting CP
    );
    localparam P2N_SZ = 200;
    localparam CTX    = 'h0d4d; /// starting context (hardcoded for now)

    typedef struct {
        `IU nfa;
        `IU pfa;
    } t_p2n;
    `U8 rom[OBUF];
    `U8 p2n_sz;
    t_p2n       p2n[P2N_SZ];

    string tib = "123 456 +";

    task add_u8(`IU ax, `U8 vx);
        repeat(1) @(posedge clk) begin
            b8_if.put_u8(ax, vx);
        end
    endtask: add_u8

    task read_rom;
        automatic `U8 c;
        automatic `DU v;
        automatic int f = $fopen("../source/eJsv32.hex", "r");
        automatic int i = 0;
        $display("ROM fed from file %d", MEM0, f);
        while (!$feof(f)) begin
            c = $fscanf(f, "%h", v);
            if (i<OBUF) rom[i] = v;
            i++;
        end
        $fclose(f);
        $display("ROM ok");
        here = i - 1;
    endtask: read_rom

    task fill_mem;
        $display("fill memory from ROM %4x-%04x", MEM0, MEM0+OBUF);
        for (int i=0; i<here; i++) begin
            add_u8(MEM0+i, i<OBUF ? rom[i] : 'h0);
        end
        ctx = CTX;
        $display("memory filled, context=%4x", CTX);
    endtask: fill_mem

    task setup_tib;
        $display("tib at x%04x: [%s]", TIB, tib);
        for (int i = 0; i < tib.len(); i++) begin
            add_u8(TIB + i, tib[i]);
        end
        add_u8(TIB + tib.len(), 'h0);
        //
        // prefetch TIB (prep for finder)
        //
        repeat(1) @(posedge clk) begin
            b8_if.we = 1'b0;
            b8_if.ai = TIB;
        end
    endtask: setup_tib

    task build_p2n;
        automatic `IU a = ctx;
        automatic integer i;
        for (i=0; a && i<P2N_SZ; i++) begin
            automatic `U8 len = rom[a] & 'h1f;
            p2n[i].nfa = a;
            p2n[i].pfa = a + len + 'h1;
            a = {rom[a-2], rom[a-1]};
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
        automatic `U8 len = rom[nfa] & 'h1f;
        for (int i=1; i<=len; i++) begin
            $write("%c", rom[nfa+i]);
        end
    endtask: to_s

    task words;
        for (int i=0; i<p2n_sz; i++) begin
            automatic `IU a = p2n[i].nfa;
            $write("%c%4x: ", rom[a] & 'h80 ? "*" : " ", a + (rom[a] & 'h1f) + 'h1);
            to_s(a);
            $display("");
        end
    endtask: words

    task setup;
        read_rom();
        fill_mem();
        build_p2n();
        words();
    endtask: setup
endmodule: dict_setup
/*
module dict_setup_tb;
    localparam TIB = 'h1000;      /// starting address of input buffer
    logic clk, rst, en;
    logic [16:0] ctx, here;

    mb8_io      b8_if();
    spram8_128k m0(b8_if.slave, clk);

    dict_setup #(DICT) dict(.*, .b8_if(b8_if.master));

    task reset;
        repeat(1) @(posedge clk) rst = 1;
        repeat(1) @(posedge clk) rst = 0;
    endtask: reset

    task verify;
        $display("validate memory content");
        // verify - read back
        for (integer i=TIB; i < TIB + 'h20; i = i + 1) begin
            repeat(1) @(posedge clk) begin
                b8_if.get_u8(i);
                $display("%x:%x", i, b8_if.vo);
            end
        end
    endtask: verify

    always #10 clk = ~clk;

    initial begin
        clk = 0;
        reset();
        dict.setup_mem();

        verify();

        #20 $finish;
    end
endmodule: dict_setup_tb
*/
