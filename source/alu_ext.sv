///
/// @file
/// @brief - ALU external modules
///    shifter    - shifter (both directions)
///    ushifter   - unsigned shifter
///    multiplier - 64-bit = 32x32
///    divider    - 32/32-bit divider
///
`include "../source/eJ32.vh"
import ej32_pkg::*;

`define DX logic[DSZ:0]        /* 1-bit wider */

module shifter #(
    parameter DSZ = 32
    )(
	input	`DU  d,
	input	`U1  dir,
	input	`U5  bits,
	output	`DU  r
    );
    assign r = dir ? d << bits : d >> bits;
endmodule

module ushifter #(
    parameter DSZ = 32
    )(
	input	`DU  d,
	input	`U5  bits,
	output	`DU  r
    );
    assign r = $unsigned(d) >> bits;
endmodule

module mult #(
    parameter DSZ = 32
    ) (
	input  `DU  a,
    input  `DU  b,
	output `DU2 r
	);
    assign r = a * b;
endmodule

module div_int #(parameter DSZ=32) (
    input  `U1  clk,
    input  `U1  rst,       // start signal
    input  `DU  x,         // dividend
    input  `DU  y,         // divisor
    output `U1  busy,      // calculation in progress
    output `U1  dbz,       // divide by zero flag
    output `DU  q,         // quotient
    output `DU  r          // remainder
    );
    logic [$clog2(DSZ)-1:0] i;        // iteration counter
    `DX r_n;               // accumulators (1 bit wider) 
    `DX r1;
    `DX ry;       
    `DU q_n;               // intermediate quotient
    `U1 pos;

    assign pos = r1 >= {1'b0, y};
    assign ry  = r1 - y;
   
    always_comb begin
        if (pos) {r_n, q_n} = {ry[DSZ-1:0], q, 1'b1}; // 65-bit ops
        else     {r_n, q_n} = {r1[DSZ-1:0], q, 1'b0};
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            i    <= 31;                // cycle counter 31->0
            q    <= 0;
            busy <= 1'b1;
            dbz  <= y == 0;
            {r1, q}  <= {{DSZ{1'b0}}, x, 1'b0};   // shift left with carry
        end
        else if (busy) begin
            if (i==0) begin            // last bit
                busy <= 1'b0;          // we are done
                r    <= r_n[DSZ:1];    // undo final shift
            end
            else r1 <= r_n;            // next digit
            q <= q_n;
            i <= i - 1;                // cycle counter
        end
    end
endmodule: div_int
