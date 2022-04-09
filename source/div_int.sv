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
    logic [DSZ:0]   _r, rx;           // accumulator (1 bit wider)
    logic [$clog2(DSZ)-1:0] i;        // iteration counter

    always_comb begin
        if (rx >= {1'b0, y}) begin
            _r = rx - y;
            {_r, _q} = {_r[DSZ-1:0], q, 1'b1};   // 65-bit ops
        end
        else {_r, _q} = {rx[DSZ-1:0], q, 1'b0};
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            i      <= 0;
            busy   <= y != 0;
            dbz    <= y == 0;
            {rx, q} <= {{DSZ{1'b0}}, x, 1'b0};
        end
        else if (busy) begin
            if (i == (DSZ-1)) begin
                busy <= 0;             // are we done?
                r    <= _r[DSZ:1];     // undo final shift
            end
            else rx  <= _r;
            q <= _q;
            i <= i + 1;
            $write("[%d] y,_q,_r=%8x,%8x,%8x ", i, y, _q, _r);
        end
    end
endmodule: div_int
