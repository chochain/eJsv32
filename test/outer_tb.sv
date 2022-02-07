///
/// eJsv32 Outer Interpreter Testbench
///
`timescale 1ps / 1ps
`include "../source/eJ32k.sv"
module outer_tb;
   logic [31:0]  addr_o_o, t_o, p_o, a_o;
   logic [7:0]   data_o_o, data_i_o, code_o;
   logic [2:0]   phase_o;
   logic [4:0]   sp_o,rp_o;
   logic         write_o; 
   logic clk, rst;

   eJsv32k u(.clk, .clr(rst), .*);
   
   task reset;
      repeat(1) @(posedge clk) rst = 1;
      repeat(1) @(posedge clk) rst = 0;
   endtask: reset

   always #5 clk  = ~clk;

   initial begin
      clk = 0;
      reset();
      
      repeat(150) @(posedge clk);
        
      #20 $finish;
   end
endmodule: outer_tb
