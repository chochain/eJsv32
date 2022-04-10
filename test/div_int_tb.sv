///
/// eJ32 div_int test bench Testbench
///
`timescale 1ps / 1ps
module div_int_tb #(
    parameter DSZ  = 32        /* 32-bit data width  */
    );

    logic          clk;
    logic[1:0]     phase;
    logic          div_rst, div_busy, div_by_z;
    logic[DSZ-1:0] s, t, div_q, div_r;

    logic[DSZ-1:0] s_vec[] = { 'h1, 'h5, 'hA, 'hC };

    div_int  #(DSZ) divide_inst (
    .clk(clk),
    .rst(div_rst),
    .x(s),
    .y(t),
    .busy(div_busy),
    .dbz(div_by_z),
    .q(div_q),
    .r(div_r)
    );

    task DIV();
        //$display("%6t>%cdiv[%d] %8x,%8x", $time, div_busy ? "*" : " ", phase, div_r, div_q);
        case (phase)
          0: begin phase = 1; div_rst = 1'b1; end
          default: begin
              if (div_busy) begin phase = 1; div_rst = 1'b0; end
              else begin phase = 0; div_rst = 1'b1; end
          end
        endcase
    endtask: DIV

    task one_loop(integer n, [DSZ-1:0] t_vec);
        for (int i=0; i<4; i++) begin
            phase   = 0;
            div_rst = 1'b1;
            s       = (s_vec[i] << n) | s_vec[i];
            t       = t_vec << n;
            $write("case %x / %x => ", s, t);
            do repeat(1) @(posedge clk)
                DIV();
            while (phase > 0);
            $display("%8x..%8x", div_q, div_r);
            assert(div_r == (s % t));
            assert(div_q == (s / t));
        end
    endtask: one_loop

    always #5 clk  = ~clk;

    initial begin
        clk = 1'b0;         // start clock

        for (int j=0; j<DSZ; j++) begin
            one_loop(j, 'h1);
        end

        #20 $finish;
    end
endmodule: div_int_tb
