///
/// eJ32 top module (Outer Interpreter)
///
`include "../source/eJ32_if.sv"

import ej32_pkg::*;

module EJ32 #(
    parameter COLD = 'h0,       ///> cold start address
    parameter MEM0 = 'h0,       ///> base memory address
    parameter TIB  = 'h1000,    ///> input buffer ptr
    parameter OBUF = 'h1400,    ///> output buffer ptr
    parameter DSZ  = 32,        ///> 32-bit data width
    parameter ASZ  = 17,        ///> 17-bit (128Kb) address width
    parameter SS_DEPTH = 32,    ///> data stack depth
    parameter RS_DEPTH = 32     ///> return stack depth
    );
    `U1  au_en, br_en, ls_en;
    // ej32 memory bus
    `IU  p;
    `U8  data;
    `DU  s;
    `U1  p_inc;
    `U1  div_bsy_o;
    `IU  br_p_o;
    `U1  br_psel;

    mb8_io      b8_if();                         ///> 8-bit memory bus
    spram8_128k smem(b8_if.slave, ~ctl.clk);     ///> tick on neg cycle

    EJ32_CTL    ctl();                           ///> ej32 control bus
    EJ32_DC     #(COLD) dc(.div_bsy(div_bsy_o), .*);
    EJ32_AU     #(SS_DEPTH, DSZ)       au(.s_o(s), .*);
    EJ32_BR     #(RS_DEPTH, DSZ, ASZ)  br(.*);
    EJ32_LS     #(TIB, OBUF, DSZ, ASZ) ls(.*);

    assign data = b8_if.vo;     ///> data fetched from SRAM (1-cycle)
    assign p    = ctl.rst       ///> instruction address
        ? COLD
        : (br_psel ? br_p_o : p + { {ASZ-1{1'b0}}, p_inc });
    ///
    /// debugging
    ///
    localparam DOT = 'h2e;      ///> '.'
    task fetch(input `IU ax, input `U2 opt);
        repeat(1) @(posedge ctl.clk) begin
            case (opt)
            'h1: $write("%02x", data);
            'h2: $write("%c", data < 'h20 ? DOT : data);
            endcase
            b8_if.get_u8(ax);
        end
    endtask: fetch
endmodule: EJ32
