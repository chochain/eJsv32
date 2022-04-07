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
    logic [DSZ:0]   _r;               // accumulator (1 bit wider)
    logic [$clog2(DSZ)-1:0] i;        // iteration counter

    always_comb begin
        if (r >= {1'b0, y}) begin
            _r = r - y;
            {_r, _q} = {_r[DSZ-1:0], q, 1'b1};
        end
        else {_r, _q} = {r, q} << 1;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            {i, dbz, busy} <= 0;
            {r, q} <= {{DSZ{1'b0}}, x, 1'b0};
        end
        else begin
            if (i != DSZ-1) begin
				busy <= y != 0;
				dbz  <= y == 0;
				r    <= _r;
			end
            else begin
                busy <= 0;             // are we done?
                r    <= _r[DSZ:1];     // undo final shift
            end
            q <= _q;
            i <= i + 1;                // advance loop counter
        end
    end
endmodule: div_int
