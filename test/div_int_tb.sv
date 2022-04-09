///
/// eJ32 div_int test bench Testbench
///
`timescale 1ps / 1ps
module div_int_tb #(
    parameter DSZ  = 32        /* 32-bit data width  */
    );

    logic          clk, rst;
    logic          div_rst, div_busy, div_by_z;
    logic[DSZ-1:0] div_q, div_r;
    logic[1:0]     phase;
    logic[DSZ-1:0] s = 'h20;
    logic[DSZ-1:0] t = 'h10;

    div_int  #(DSZ) divide_inst (
    .clk(clk),
    .rst(rst),
    .x(s),
    .y(t),
    .busy(div_busy),
    .dbz(div_by_z),
    .q(div_q),
    .r(div_r)
    );

    task DIV();
        case (phase)
          0: begin phase = 1; rst = 1'b0; end
          1: begin phase = div_busy ? 1 : 2; rst = 1'b0; end
          default: begin phase = 0; rst = 1'b1; end
        endcase
        $display("%6t>%c%d %8x,%8x", $time, div_busy ? "*" : " ", phase, div_q, div_r);
    endtask: DIV

    always #5 clk  = ~clk;

    initial begin
        clk   = 1'b0;         // start clock
        rst   = 1'b1;         // enable divider
        phase = 0;

        repeat(40) @(posedge clk) begin
           DIV();
        end
        rst = 1'b1;           // disable divider

        #20 $finish;
    end
endmodule: div_int_tb
