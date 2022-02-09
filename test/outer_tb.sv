///
/// eJsv32 Outer Interpreter Testbench
///
`timescale 1ps / 1ps
`include "../source/forthsuper_if.sv"
`include "../source/eJ32.sv"
module outer_tb #(
   parameter DICT = 'h0,
   parameter ASZ  = 17
   );
   logic[31:0]     addr_o_o, t_o, p_o, a_o;
   logic[7:0]      data_o_o, data_o_i, code_o;
   logic[2:0]      phase_o;
   logic[4:0]      sp_o, rp_o;
   logic           write_o; 

   logic           clk, rst;
   logic [ASZ-1:0] ctx, here;
   
   mb8_io      b8_if();
   spram8_128k m0(b8_if.slave, ~clk);

   dict_setup  #(DICT) dict(.*, .b8_if(b8_if.master));
   eJ32        u(.clk, .clr(rst), .*);
   
    task verify; 
        $display("validate memory content");
        // verify - read back
        for (integer i=DICT; i < DICT + 'h8; i = i + 1) begin
            repeat(1) @(posedge clk) begin
                b8_if.get_u8(i);
                $display("%x:%x", i, b8_if.vo);
            end
        end
    endtask: verify

   task reset;
      b8_if.get_u8(0);
      repeat(1) @(posedge clk) rst = 1;
      repeat(1) @(posedge clk) rst = 0;
   endtask: reset

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
      verify();             // validate memory content
      
      reset();              // activate eJsv32
      repeat(150) @(posedge clk);
        
      #20 $finish;
   end
endmodule: outer_tb
