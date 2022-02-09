///
/// ForthSuper Dictionary Setup Testbench
///
`timescale 1ps / 1ps
`include "../source/forthsuper_if.sv"
module dict_setup #(
    parameter TIB  = 'h0,
    parameter DICT = 'h0,       /// starting address of dictionary
    parameter DSZ  = 8,         /// 8-bit data path
    parameter ASZ  = 17         /// 128K address space
    ) (
    mb8_io b8_if,               /// 8-bit memory bus master
    input  clk,
    output logic [ASZ-1:0] ctx,
    output logic [ASZ-1:0] here
    );
    string tib = "123 456 +";
    
    task add_u8([16:0] ax, [7:0] vx);
        repeat(1) @(posedge clk) begin
            b8_if.put_u8(ax, vx);
        end
    endtask: add_u8
    
    task setup_mem;
        automatic integer c, i = DICT;
        automatic integer f = $fopen("../source/eJsv32.hex", "r");
        logic [7:0] v;
        
        $display("fill memory at x%04x from file %d", i, f);
        while (!$feof(f)) begin
            c = $fscanf(f, "%h", v);
            add_u8(i++, v);
        end
        $fclose(f);
        ctx  = i;
        here = i;
        $display("done memory at x%04x:", i);
    endtask: setup_mem
    
    task setup_tib;
        $display("tib at x%04x: [%s]", TIB, tib);
        for (integer i = 0; i < tib.len(); i = i + 1) begin
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
endmodule: dict_setup
/*
module dict_setup_tb;
    localparam DICT = 'h0;      /// starting address of dictionary
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
        for (integer i=DICT; i < DICT + 'h20; i = i + 1) begin
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
