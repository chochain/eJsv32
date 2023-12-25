///
/// eJ32 top module (Outer Interpreter)
///
`include "../source/eJ32.vh"
`include "../source/eJ32_if.sv"

import ej32_pkg::*;

module eJ32 #(
    parameter TIB  = 'h1000,    // input buffer ptr
    parameter OBUF = 'h1400     // output buffer ptr
    );
    // ej32 memory bus
    `IU  addr;                  ///> shared memory address
    `U8  data;                  ///> data return from SRAM (sent to core)
    `U8  data_o;                ///> data return from core
    `U1  dwe_o;                 ///> data write enable driven by core

    mb8_io      b8_if();        ///> memory bus
    ej32_ctl    ctl();          ///> ej32 control bus
   
    spram8_128k smem(b8_if.slave, ~ctl.clk);
    ej32_core #(TIB, OBUF) core(.ctl(ctl), .data_i(data), .addr_o(addr), .*);

    assign data = b8_if.vo;     ///> data fetched from SRAM (1-cycle)
   
    always_comb begin
        if (dwe_o) b8_if.put_u8(addr, data_o);  ///> write to SRAM
        else       b8_if.get_u8(addr);          ///> read from SRAM
    end
    ///
    /// debugging
    ///
    localparam DOT = 'h2e;      ///> '.'
    task fetch(input `IU ax, input `U2 opt);
        repeat(1) @(posedge ctl.clk) begin
            case (opt)
            'h1: $write("%02x", b8_if.vo);
            'h2: $write("%c", b8_if.vo < 'h20 ? DOT : b8_if.vo);
            endcase
            b8_if.get_u8(ax);
        end
    endtask: fetch
endmodule: eJ32
