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
    parameter ROM_SZ   = 8192,  ///> ROM hosted eForth image size in bytes
    parameter ROM_WAIT = 3      ///> wait cycle to stablize ROM read
    ) (
    input `U1 clk, rst /*synthesis syn_force_pads=1 syn_noprune=1*/
    );
    `U1  au_en, br_en, ls_en;   ///> unit enables
    `U1  dc_en, rom_en;
    `IU  p, p_n;                ///> program counter
    `U8  rom_wait;              ///> ROM wait cycles for EBR to stablize read
    `IU  rom_a;                 ///> ROM address pointer
    `U8  rom_d, data;           ///> data return from memory bus
    `U1  p_inc;                 ///> program counter advance flag
    `U1  div_bsy_o;             ///> AU divider busy flag
    `DU  s_o;                   ///> NOS (AU -> LS)
    `IU  br_p_o;                ///> BR branching target
    `U1  br_psel;               ///> BR branching target select
    `DU  au_t_o, br_t_o, ls_t_o;///> TOS from modules for arbitration
    `U1  au_t_x, br_t_x, ls_t_x;
    ///
    /// EJ32 buses
    ///
    EJ32_CTL    ctl();                           ///> ej32 control bus
    mb8_io      b8_if();                         ///> 8-bit memory bus
    ///
    /// memory blocks
    ///
    spram8_128k smem(b8_if.slave, ~clk);         ///> SPRAM, (neg edged)
    EJ32_ROM    rom(.clk(~clk), .*);             ///> ROM, eForth image (neg edged)
    ///
    /// EJ32 core modules
    ///
    EJ32_DC     dc(.div_bsy(div_bsy_o), .*);     ///> decoder unit
    EJ32_AU     au(.*);                          ///> arithmetic unit
    EJ32_BR     br(.*);                          ///> branching unit
    EJ32_LS     #(TIB, OBUF) ls(.s(s_o), .*);    ///> load/store unit
    ///
    /// eForth image loader from ROM into RAM
    ///
    task COPY_ROM();
        if (rom_wait > 0) begin
            p_n    <= 'h0;
            rom_a  <= 'h0;
            rom_wait <= rom_wait - 1;
        end
        else if (rom_a < ROM_SZ) begin           ///> copy ROM into RAM byte-by-byte
            p_n    <= rom_a - 1;                 ///> RAM is 1-cycle behind
            rom_a  <= rom_a + 1;
            ctl.t  <= {{`ASZ-8{1'b0}}, rom_d};
        end
        else begin
            p_n    <= COLD;                      ///> switch on DC, cold start address
            rom_en <= 1'b0;                      ///> disable ROM
            dc_en  <= 1'b1;                      ///> activate decoder
        end
    endtask: COPY_ROM
    ///
    /// TOS update arbitrator
    ///
    task UPDATE_TOS();
        automatic `U3 sel = { au_t_x, br_t_x, ls_t_x };
        case (sel)
        3'b000: begin end // OK, ctl.t stays the same
        3'b100: ctl.t <= au_t_o;
        3'b010: ctl.t <= br_t_o;
        3'b001: ctl.t <= ls_t_o;
        default: $display("TOS Arbiter ERR t_x=%x", sel);
        endcase
    endtask: UPDATE_TOS
    ///
    /// Instruction Unit
    ///
/* iCE40up5k high speed clock (48MHz) in built-in library
    `U1 clk0;
    HSOSC #(.CLKHF_DIV("b01")) clock(            // 48MHz divide by 2
    .CLKHFEN(1'b1),                              // Enable the output  
    .CLKHFPU(1'b1),                              // Power up the oscillator  
    .CLKHF(clk)                                  // Oscillator output  
    );
*/   
    assign ctl.clk = clk;                        ///> clock driver
    assign ctl.rst = rst;
    assign p       = br_psel ? br_p_o : p_n;     ///> branch target
    assign data    = b8_if.vo;                   ///> data fetched from SRAM (1-cycle)

    always_ff @(posedge clk) begin
        if (rst) begin
            rom_a     <= 0;                      ///> ROM address pointer
            dc_en     <= 1'b0;
            rom_en    <= 1'b1;
            rom_wait  <= ROM_WAIT;               ///> wait 3-cycles for ROM to be read ready
        end
        else if (rom_en) COPY_ROM();             ///> copy eForth image from ROM into RAM
        else begin
            UPDATE_TOS();                        ///> arbitrate TOS update
            p_n <= p + {{`ASZ-1{1'b0}}, p_inc};  ///> advance instruction address
        end
    end
endmodule: EJ32
