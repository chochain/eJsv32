///
/// @file
/// @brief - ALU extended funtions
///    shifter    - shifter (both directions)
///    ushifter   - unsigned shifter
///    multiplier - 64-bit = 32x32
///    divider    -
///
module shifter #(
    parameter DSZ = 32
    )(
	input	[DSZ-1:0] d,
	input	          dir,
	input	[4:0]     bits,
	output	[DSZ-1:0] r
    );
    assign r = dir ? d << bits : d >> bits;
endmodule

module ushifter #(
    parameter DSZ = 32
    )(
	input	[DSZ-1:0]  d,
	input	[4:0]      bits,
	output	[DSZ-1:0]  r
    );
    assign r = $unsigned(d) >> bits;
endmodule

module mult #(
    parameter DSZ = 32,
    parameter QSZ = DSZ*2
    )(
	input  [DSZ-1:0] a, b,
	output [QSZ-1:0] r
	);
    assign r = a * b;
endmodule

module div_int #(parameter DSZ=32) (
    input  logic clk,
    input  logic rst,                 // start signal
    input  logic [DSZ-1:0] x,         // dividend
    input  logic [DSZ-1:0] y,         // divisor
    output logic busy,                // calculation in progress
    output logic dbz,                 // divide by zero flag
    output logic [DSZ-1:0] q,         // quotient
    output logic [DSZ-1:0] r          // remainder
    );
    logic [DSZ-1:0] _q;               // intermediate quotient
    logic [DSZ:0]   _r, r1;           // accumulator (1 bit wider)
    logic [$clog2(DSZ)-1:0] i;        // iteration counter

    always_comb begin
        if (r1 >= {1'b0, y}) begin
            {_r, _q} = {{r1 - y}[DSZ-1:0], q, 1'b1}; // 65-bit ops
        end
        else {_r, _q} = {r1[DSZ-1:0], q, 1'b0};
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            i      <= 1;
            busy   <= 1'b1;
            dbz    <= y == 0;
            {r1, q} <= {{(DSZ-1){1'b0}}, x, 1'b0};   // shift left with carry
        end
        else if (busy) begin
            if (i) r1 <= _r;           // next digit
            else begin                 // last bit
                busy <= 1'b0;          // we are done
                r    <= _r[DSZ:1];     // undo final shift
            end
            q <= _q;
            i <= i + 1;
            //$write("[%d] r1.q _r_q %9x.%8x %9x_%8x ", i, r1, q, _r, _q);
        end
    end
endmodule: div_int
