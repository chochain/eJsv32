///
/// eJ32 module - ROM (host eForth image)
///
`include "../source/eJ32_if.sv"
import ej32_pkg::*;

module EJ32_ROM #(
    parameter ROM_SZ = 8192
    ) (
    input  `U1 clk,
    input  `U1 rst,
    input  `IU rom_a,
    output `U8 rom_d
    );
    localparam MSZ = $clog2(ROM_SZ);
    `U8 d_o;
    ///
    /// 8K EBR ROM (for eForth image 3.4K and TIB at 'h1000)
    ///
    brom8k rom(
        .rd_clk_i(clk),
        .rst_i(rst),
        .rd_en_i(~rst),
        .rd_clk_en_i(~rst),          // clk_en=1'b0: low power mode
        .rd_addr_i(rom_a[MSZ-1:0]),
        .rd_data_o(d_o)
    );

    assign rom_d = d_o;
endmodule: EJ32_ROM
