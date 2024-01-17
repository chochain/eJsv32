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
    parameter RS_DEPTH = 64,    ///> return stack depth (v2 - hardcoded in ERB netlist)
    parameter ROM_SZ   = 8192,  ///> ROM hosted eForth image size in bytes
    parameter ROM_WAIT = 3      ///> wait cycle to stablize ROM read
    );
    `U1  au_en, br_en, ls_en;   ///> unit enables
    `U1  dc_en, rom_en;
    `U8  rom_wait;              ///> ROM wait cycles for EBR to stablize read
    `IU  p, p_n;                ///> program counter
    `IU  rom_a;                 ///> ROM address pointer
    `U8  rom_d, data;           ///> data return from memory bus
    `DU  s;                     ///> NOS
    `U1  p_inc;                 ///> program counter advance flag
    `U1  div_bsy_o;             ///> AU divider busy flag
    `IU  br_p_o;                ///> BR branching target
    `U1  br_psel;               ///> BR branching target select
    ///
    /// EJ32 buses
    ///
    EJ32_CTL    ctl();                           ///> ej32 control bus
    mb8_io      b8_if();                         ///> 8-bit memory bus
    ///
    /// memory blocks
    ///
    spram8_128k smem(b8_if.slave, ~ctl.clk);     ///> SPRAM, (neg edged)
    EJ32_ROM    rom(                             ///> ROM, eForth image
        .clk(~ctl.clk), .rst(ctl.rst), .*);
    ///
    /// EJ32 core modules
    ///
    EJ32_DC     dc(.div_bsy(div_bsy_o), .*);     ///> decoder unit
    EJ32_AU     #(DSZ)       au(.s_o(s), .*);    ///> arithmetic unit
    EJ32_BR     #(DSZ, ASZ)  br(.*);             ///> branching unit
    EJ32_LS     #(TIB, OBUF, DSZ, ASZ) ls(.*);   ///> load/store unit
    ///
    /// eForth image loader from ROM into RAM
    ///
    task COPY_ROM();
        if (rom_wait > 0) begin
            rom_wait <= rom_wait - 1;
        end
        else if (rom_a < ROM_SZ) begin           ///> copy ROM into RAM byte-by-byte
            p_n    <= rom_a - 1;                 ///> RAM is 1-cycle behind
            rom_a  <= rom_a + 1;
            ctl.t  <= {{ASZ-8{1'b0}}, rom_d};
       end
       else begin
            p_n    <= COLD;                      ///> switch on DC, cold start address
            rom_en <= 1'b0;                      ///> disable ROM
            dc_en  <= 1'b1;                      ///> activate decoder
       end
    endtask: COPY_ROM
    ///
    /// Instruction Unit
    ///
    assign p       = br_psel ? br_p_o : p_n;     ///> branch target
    assign data    = b8_if.vo;                   ///> data fetched from SRAM (1-cycle)

    always_ff @(posedge ctl.clk) begin
        if (ctl.rst) begin
            rom_a     <= 0;                      ///> ROM address pointer
            dc_en     <= 1'b0;
            rom_en    <= 1'b1;
            rom_wait  <= ROM_WAIT;               ///> wait 3-cycles for ROM to be read ready
        end
        else if (rom_en) COPY_ROM();             ///> copy eForth image from ROM into RAM
        else p_n <= p + {{ASZ-1{1'b0}}, p_inc};  ///> advance instruction address
    end
endmodule: EJ32
