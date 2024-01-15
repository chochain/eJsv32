///
/// eJ32 top module + Instruction unit
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
    parameter SS_DEPTH = 64,    ///> data stack depth (v2 - hardcoded in ERB netlist)
    parameter RS_DEPTH = 64     ///> return stack depth (v2 - hardcoded in ERB netlist)
    );
    `U1  au_en, br_en, ls_en;   ///> unit enables
    `IU  p, p_n;                ///> program counter
    `U8  data;                  ///> data return from memory bus
    `DU  s;                     ///> NOS
    `U1  p_inc;                 ///> program counter advance flag
    `U1  div_bsy_o;             ///> AU divider busy flag
    `IU  br_p_o;                ///> BR branching target
    `U1  br_psel;               ///> BR branching target select
    ///
    /// RAM block
    ///
    mb8_io      b8_if();                         ///> 8-bit memory bus
    spram8_128k smem(b8_if.slave, ~ctl.clk);     ///> tick on neg cycle
    ///
    /// EJ32 core
    ///
    EJ32_CTL    ctl();                           ///> ej32 control bus
    EJ32_DC     dc(.div_bsy(div_bsy_o), .*);     ///> decoder unit
    EJ32_AU     #(DSZ)       au(.s_o(s), .*);    ///> arithmetic unit
    EJ32_BR     #(DSZ, ASZ)  br(.*);             ///> branching unit
    EJ32_LS     #(TIB, OBUF, DSZ, ASZ) ls(.*);   ///> load/store unit
    ///
    /// Instruction Unit
    ///
    assign p = br_psel ? br_p_o : p_n;   ///> branch target
    assign data = b8_if.vo;              ///> data fetched from SRAM (1-cycle)
   
    always_ff @(posedge ctl.rst, posedge ctl.clk) begin
        if (ctl.rst) begin
            p_n <= COLD;                 ///> cold start address
        end
        else if (ctl.clk) begin
            p_n <= (p + { {ASZ-1{1'b0}}, p_inc });
        end
    end
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
