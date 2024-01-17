///
/// eJ32 module - ROM (host eForth image)
///
`include "../source/eJ32_if.sv"
import ej32_pkg::*;

module EJ32_ROM (
    input  `U1 clk,
    input  `U1 rst,
    input  `IU rom_a,
    output `U8 rom_d
    );
    `U8 d_o;
    ///
    /// 8K EBR ROM (for eForth image 3.4K and TIB at 'h1000)
    ///
    brom8k rom(
        .rd_clk_i(clk),
        .rst_i(rst),
        .rd_en_i(~rst),
        .rd_clk_en_i(1'b1),
        .rd_addr_i(rom_a[12:0]),
        .rd_data_o(d_o)
    );

    assign rom_d = d_o;
endmodule: EJ32_ROM
