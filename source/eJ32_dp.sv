//
// eJ32 - Java Forth Machine - Data Processor
//
`include "../source/eJ32_if.sv"

module EJ32_DP (
    EJ32_CTL ctl,
    input    `U1 dp_en,         ///> arithmetic unit enable
    input    `DU s,             ///> NOS
    output   `U1 dp_bsy_o,      ///> divider busy flag
    output   `DU dp_t_o,        ///> divider result
    output   `U1 dp_t_x         ///> TOS update flag
    );
    import ej32_pkg::*;
    /// @defgroup Registers
    /// @{
    `DU t_n;                    ///> next TOS
    /// @}
    /// @defgroup Wires
    /// @{
    opcode_t code;              ///> shadow ctl.code
    `U3 phase;                  ///> FSM phase (aka state)
    `DU t;
    `U1 t_x;                    ///> TOS update flag
    /// @}
    /// @defgroup ALU pre-calc wires
    /// @{
    `DU  isht, iushr;
    `DU2 mul_v;
    `U1  div_bsy;
    `DU  div_q, div_r, div_v;
    `U1  div_z, shr_f;
    /// @}
    ///
    /// Extended Arithmetic units
    ///
    mult      mult_inst(
    .a(t),
    .b(s),
    .r(mul_v)
    );
    div_int   div_inst(
    .clk(ctl.clk),
    .rst(~dp_en),
    .x(s),
    .y(t),
    .busy(div_bsy),
    .z(div_z),
    .q(div_q),
    .r(div_r)
    );
    shifter   shifter_inst(
    .d(s),
    .dir(shr_f),
    .bits(t[4:0]),
    .r(isht)
    );
    ushifter  ushifter_inst(
    .d(s),
    .bits(t[4:0]),
    .r(iushr)
    );
    // data stack tasks (as macros)
    task TOS(input `DU v); t_n = v; `SET(t_x); endtask
    task DIV(input `DU v); if (phase==1 && !div_bsy) TOS(v); endtask
    ///
    /// wires to reduce verbosity
    ///
    assign code   = ctl.code;               ///> input from ej32 control
    assign phase  = ctl.phase;
    assign t      = ctl.t;
    ///
    /// wired to output
    ///
    assign dp_bsy_o = div_bsy;
    assign dp_t_o   = t_n;
    assign dp_t_x   = t_x;
    ///
    /// combinational
    ///
    always_comb begin
        t_n   = 'hddfeeddd;
        t_x   = 1'b0;
        shr_f = 1'b0;         /// shift left
        ///
        /// instruction dispatcher
        ///
        case (code)
        imul:  TOS(mul_v[`DSZ-1:0]);
        idiv:  DIV(div_q);
        irem:  DIV(div_r);
        ishl:  TOS(isht);
        ishr:  begin `SET(shr_f); TOS(isht); end
        iushr: TOS(iushr);
        endcase
    end
   
    always_ff @(posedge ctl.clk) begin
        if (ctl.rst) begin
            div_v <= t;
        end
        else if (dp_en) begin
            div_v <= code==idiv ? div_q : (code==irem ? div_r : t);
           
            if (!div_bsy) div_check();
         end
    end

    task div_check();
        automatic `U8 op  = code==idiv ? "/" : "%";
        case (phase)
        1: begin             // done div_int
            assert(div_q == (s / t) && div_r == (s % t)) else begin
                $display("AU.1.ERR %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
            end
        end
        endcase
    endtask: div_check
endmodule: EJ32_DP
